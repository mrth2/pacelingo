import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/profile.dart';
import '../models/session.dart';
import '../models/session_summary.dart';
import '../services/firebase_service.dart';
import '../services/firestore_service.dart';
import '../services/gemini_service.dart';

/// Represents the current audio/UI state of the chat screen.
enum ChatAudioState {
  idle,
  listening,
  processing,
  speaking,
}

/// Manages chat state, audio recording, AI responses, and Firestore persistence
/// for a single tutoring session.
class ChatProvider extends ChangeNotifier {
  final GeminiService _geminiService;
  final FirestoreService _firestoreService;
  final FirebaseService _firebaseService;
  final SpeechToText _speechToText;
  final FlutterTts _flutterTts;

  // Session state
  String? _sessionId;
  String? _userId;
  Profile? _profile;
  String? _previousSessionSummary;
  String? _lessonModePrompt;
  final List<ChatMessage> _messages = [];

  // Audio state
  ChatAudioState _audioState = ChatAudioState.idle;
  String _liveTranscript = '';

  // Error state
  String? _error;

  ChatProvider({
    required GeminiService geminiService,
    FirestoreService? firestoreService,
    FirebaseService? firebaseService,
    SpeechToText? speechToText,
    FlutterTts? flutterTts,
  })  : _geminiService = geminiService,
        _firestoreService = firestoreService ?? FirestoreService(),
        _firebaseService = firebaseService ?? FirebaseService(),
        _speechToText = speechToText ?? SpeechToText(),
        _flutterTts = flutterTts ?? FlutterTts() {
    _initTts();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatAudioState get audioState => _audioState;
  String get liveTranscript => _liveTranscript;
  bool get isListening => _audioState == ChatAudioState.listening;
  bool get isProcessing => _audioState == ChatAudioState.processing;
  bool get isSpeaking => _audioState == ChatAudioState.speaking;
  bool get hasError => _error != null;
  String? get error => _error;
  Profile? get profile => _profile;
  String? get lessonModePrompt => _lessonModePrompt;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      _audioState = ChatAudioState.idle;
      notifyListeners();
    });
    _flutterTts.setLanguage('en-US');
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
  }

  /// Initialises a new session for [userId] using [profile].
  ///
  /// An optional [lessonModePrompt] can be provided to inject lesson-mode
  /// specific rules into the system prompt for the entire session.
  Future<void> startSession({
    required String userId,
    required Profile profile,
    String? lessonModePrompt,
  }) async {
    _userId = userId;
    _profile = profile;
    _lessonModePrompt = lessonModePrompt;
    _messages.clear();
    _error = null;

    // Load the most recent session summary for context continuity.
    final lastSession = await _firestoreService.getLastSession(
      userId: userId,
      profileId: profile.id,
    );
    _previousSessionSummary = lastSession?.autoSummary;

    // Create a new session in Firestore.
    _sessionId = await _firestoreService.createSession(
      userId: userId,
      profileId: profile.id,
    );

    // Send an opening greeting from the tutor.
    await _sendAIGreeting();

    notifyListeners();
  }

  Future<void> _sendAIGreeting() async {
    if (_profile == null) return;
    const greetingPrompt =
        'Start the session with a warm, encouraging greeting tailored to the learner. '
        'Ask what they would like to practise today (e.g. vocabulary, pronunciation, conversation).';
    await _callGemini(greetingPrompt, persistUserMessage: false);
  }

  // ---------------------------------------------------------------------------
  // Push-to-Talk
  // ---------------------------------------------------------------------------

  /// Begins recording the user's voice input.
  ///
  /// If the AI is currently speaking, interrupts TTS first and then starts
  /// listening (walkie-talkie style interruption).
  Future<void> startListening() async {
    // Handle interruption: stop TTS if AI is speaking, then start listening.
    if (_audioState == ChatAudioState.speaking) {
      await _flutterTts.stop();
      _audioState = ChatAudioState.idle;
      notifyListeners();
    }

    if (_audioState != ChatAudioState.idle) return;

    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          _error = 'Speech recognition error: ${error.errorMsg}';
          _audioState = ChatAudioState.idle;
          notifyListeners();
        },
      );

      if (!available) {
        _error =
            'Microphone not available. Please ensure microphone permissions '
            'are granted in your browser settings and try again.';
        notifyListeners();
        return;
      }
    } catch (e) {
      _error = 'Microphone permission denied. On Web/PWA, please allow '
          'microphone access when prompted by the browser.';
      _audioState = ChatAudioState.idle;
      notifyListeners();
      return;
    }

    _audioState = ChatAudioState.listening;
    _liveTranscript = '';
    _error = null;
    notifyListeners();

    _speechToText.listen(
      onResult: (result) {
        _liveTranscript = result.recognizedWords;
        notifyListeners();

        if (result.finalResult && _liveTranscript.isNotEmpty) {
          _onSpeechResult(_liveTranscript);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      cancelOnError: true,
    );
  }

  /// Stops recording and submits the transcript to the AI.
  Future<void> stopListening() async {
    if (_audioState != ChatAudioState.listening) return;
    await _speechToText.stop();
    if (_liveTranscript.isNotEmpty) {
      await _onSpeechResult(_liveTranscript);
    } else {
      _audioState = ChatAudioState.idle;
      notifyListeners();
    }
  }

  Future<void> _onSpeechResult(String transcript) async {
    _liveTranscript = '';
    await _callGemini(transcript, persistUserMessage: true);
  }

  // ---------------------------------------------------------------------------
  // Text Input
  // ---------------------------------------------------------------------------

  /// Sends a [text] message typed by the user.
  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    await _callGemini(text.trim(), persistUserMessage: true);
  }

  // ---------------------------------------------------------------------------
  // AI Communication
  // ---------------------------------------------------------------------------

  Future<void> _callGemini(
    String userText, {
    required bool persistUserMessage,
  }) async {
    if (_profile == null || _sessionId == null || _userId == null) return;

    _error = null;
    _audioState = ChatAudioState.processing;
    notifyListeners();

    // Persist and record the user message.
    if (persistUserMessage) {
      final userMessage = ChatMessage(
        role: 'user',
        text: userText,
        timestamp: DateTime.now(),
      );
      _messages.add(userMessage);
      await _firestoreService.appendMessage(
        sessionId: _sessionId!,
        message: userMessage,
      );
      notifyListeners();
    }

    try {
      final response = await _geminiService
          .sendMessage(
            userMessage: userText,
            profile: _profile!,
            chatHistory: _messages,
            previousSessionSummary: _previousSessionSummary,
            lessonModePrompt: _lessonModePrompt,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw GeminiServiceException('AI response timed out after 30 seconds. Please try again.'),
          );

      final aiMessage = ChatMessage(
        role: 'model',
        text: response,
        timestamp: DateTime.now(),
      );
      _messages.add(aiMessage);
      await _firestoreService.appendMessage(
        sessionId: _sessionId!,
        message: aiMessage,
      );

      _audioState = ChatAudioState.speaking;
      notifyListeners();
      await _flutterTts.speak(response);
    } on GeminiServiceException catch (e) {
      _error = e.message;
      _audioState = ChatAudioState.idle;
      notifyListeners();
    }
  }

  /// Clears the current error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Session End
  // ---------------------------------------------------------------------------

  /// Ends the session: generates an AI summary and structured analysis,
  /// saves them to Firestore, and returns the [SessionSummary].
  ///
  /// Returns `null` if there is no active session or messages.
  Future<SessionSummary?> endSession() async {
    if (_sessionId == null || _profile == null || _messages.isEmpty) return null;

    SessionSummary summary = const SessionSummary.empty();

    try {
      // Generate the traditional text summary for Firestore continuity.
      final textSummary = await _geminiService.generateSessionSummary(
        profile: _profile!,
        chatHistory: _messages,
      );
      await _firestoreService.updateSessionSummary(
        sessionId: _sessionId!,
        summary: textSummary,
      );

      // Generate structured JSON analysis for the summary screen.
      final rawAnalysis = await _geminiService.analyzeSession(
        profile: _profile!,
        chatHistory: _messages,
      );
      summary = SessionSummary.fromGeminiResponse(rawAnalysis);

      // Save structured summary to Firestore.
      await _firebaseService.saveSessionSummary(
        sessionId: _sessionId!,
        userId: _userId!,
        summary: summary,
      );

      // Update the user's profile with the next_focus for the next session.
      if (summary.nextFocus.isNotEmpty) {
        await _firebaseService.updateUserProfileContext(
          profileId: _profile!.id,
          nextFocus: summary.nextFocus,
        );
      }
    } catch (_) {
      // Summary generation is best-effort; don't block the user from leaving.
    }

    await _flutterTts.stop();
    await _speechToText.stop();
    _messages.clear();
    _sessionId = null;
    _audioState = ChatAudioState.idle;
    notifyListeners();

    return summary;
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }
}
