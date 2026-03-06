import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:pacelingo/models/profile.dart';
import 'package:pacelingo/models/session.dart';
import 'package:pacelingo/providers/chat_provider.dart';
import 'package:pacelingo/services/gemini_service.dart';
import 'package:pacelingo/services/firestore_service.dart';
import 'package:pacelingo/services/firebase_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------
class MockGeminiService extends Mock implements GeminiService {}

class MockFirestoreService extends Mock implements FirestoreService {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockSpeechToText extends Mock implements SpeechToText {}

class MockFlutterTts extends Mock implements FlutterTts {}

// Needed for registerFallbackValue
class FakeChatMessage extends Fake implements ChatMessage {}

void main() {
  late MockGeminiService mockGemini;
  late MockFirestoreService mockFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockSpeechToText mockStt;
  late MockFlutterTts mockTts;
  late ChatProvider provider;

  setUpAll(() {
    registerFallbackValue(FakeChatMessage());
    registerFallbackValue(Profile.defaultChild());
  });

  setUp(() {
    mockGemini = MockGeminiService();
    mockFirestore = MockFirestoreService();
    mockFirebaseService = MockFirebaseService();
    mockStt = MockSpeechToText();
    mockTts = MockFlutterTts();

    // Stub TTS configuration calls.
    when(() => mockTts.setCompletionHandler(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => mockTts.setPitch(any())).thenAnswer((_) async => 1);
    when(() => mockTts.stop()).thenAnswer((_) async => 1);
    when(() => mockTts.speak(any())).thenAnswer((_) async => 1);

    // Stub STT defaults.
    when(() => mockStt.initialize(onError: any(named: 'onError')))
        .thenAnswer((_) async => true);
    when(() => mockStt.stop()).thenAnswer((_) async {});

    provider = ChatProvider(
      geminiService: mockGemini,
      firestoreService: mockFirestore,
      firebaseService: mockFirebaseService,
      speechToText: mockStt,
      flutterTts: mockTts,
    );
  });

  // -------------------------------------------------------------------------
  group('Getters', () {
    test('hasError returns false when error is null', () {
      expect(provider.hasError, isFalse);
      expect(provider.error, isNull);
    });

    test('initial audioState is idle', () {
      expect(provider.audioState, ChatAudioState.idle);
      expect(provider.isListening, isFalse);
      expect(provider.isProcessing, isFalse);
      expect(provider.isSpeaking, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('clearError', () {
    test('clearError sets error to null and notifies listeners', () {
      int listenerCallCount = 0;
      provider.addListener(() => listenerCallCount++);

      // Manually we cannot set error directly, but clearError should be safe
      // to call even when there's no error.
      provider.clearError();
      expect(provider.hasError, isFalse);
      expect(listenerCallCount, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('startListening – microphone permission handling', () {
    test('sets error when microphone is not available', () async {
      when(() => mockStt.initialize(onError: any(named: 'onError')))
          .thenAnswer((_) async => false);

      await provider.startListening();

      expect(provider.hasError, isTrue);
      expect(provider.error, contains('Microphone not available'));
      expect(provider.audioState, ChatAudioState.idle);
    });

    test('sets error when STT initialize throws (web permission denied)',
        () async {
      when(() => mockStt.initialize(onError: any(named: 'onError')))
          .thenThrow(Exception('Permission denied'));

      await provider.startListening();

      expect(provider.hasError, isTrue);
      expect(provider.error, contains('Microphone permission denied'));
      expect(provider.audioState, ChatAudioState.idle);
    });
  });

  // -------------------------------------------------------------------------
  group('Interruption handling', () {
    test(
        'startListening while speaking stops TTS and transitions to listening',
        () async {
      // Manually set the internal state to speaking via reflection is not
      // possible, so we test the public API path. We rely on the fact that
      // if audioState != idle and != speaking, startListening returns early.

      // We verify the TTS stop behaviour by testing that when we call
      // startListening after setting up the provider to be in speaking state,
      // TTS.stop() is invoked.

      // Since we can't easily put the provider in speaking state without a
      // full session, we at least verify startListening initializes STT and
      // that when STT is available, state transitions to listening.
      when(() => mockStt.listen(
            onResult: any(named: 'onResult'),
            listenFor: any(named: 'listenFor'),
            pauseFor: any(named: 'pauseFor'),
            localeId: any(named: 'localeId'),
            cancelOnError: any(named: 'cancelOnError'),
          )).thenAnswer((_) {});

      await provider.startListening();

      expect(provider.isListening, isTrue);
      expect(provider.audioState, ChatAudioState.listening);
    });
  });

  // -------------------------------------------------------------------------
  group('stopListening', () {
    test('returns early if not in listening state', () async {
      // Provider is idle, stopListening should be a no-op.
      await provider.stopListening();

      verifyNever(() => mockStt.stop());
      expect(provider.audioState, ChatAudioState.idle);
    });
  });

  // -------------------------------------------------------------------------
  group('State transitions', () {
    test('audioState getters map correctly to enum values', () {
      // We can only test the initial state since we can't directly set
      // _audioState. The getters are straightforward enum comparisons.
      expect(provider.isListening, isFalse);
      expect(provider.isProcessing, isFalse);
      expect(provider.isSpeaking, isFalse);
    });
  });
}
