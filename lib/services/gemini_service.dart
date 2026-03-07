import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/profile.dart';
import '../models/session.dart';

/// Encapsulates Gemini API interactions and implements the Prompt Orchestrator
/// logic that combines role definition, profile data, lesson rules, and
/// previous session context into a coherent, personalized system prompt.
class GeminiService {
  static const String _baseSystemRole = '''
You are PaceLingo, a dedicated and adaptive English language tutor.
Your teaching style adapts to each learner's age, proficiency level, and goals.
You ALWAYS respond in English unless the student is completely stuck, in which case
you may briefly clarify in simple terms.
You NEVER correct without encouragement; always praise the effort before correcting.
You keep responses concise and conversational to maintain an engaging dialogue pace.
''';

  static const String _correctionProtocol = '''
CORRECTION PROTOCOL:
- When the user makes a pronunciation or grammar error, gently highlight it.
- Provide the correct form once, clearly.
- Ask the user to try again immediately.
- If the user repeats the same mistake, offer a simplified explanation and repeat
  the correction exercise. Persist until they get it right (up to 3 attempts).
- After a successful correction, celebrate the improvement enthusiastically.
''';

  final GenerativeModel _model;

  /// Constructs a [GeminiService] with the given API key.
  ///
  /// The [apiKey] must be a valid Google AI Studio / Gemini API key.
  GeminiService({required String apiKey})
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
        );

  // ---------------------------------------------------------------------------
  // Prompt Orchestrator
  // ---------------------------------------------------------------------------

  /// Builds the full system prompt by concatenating:
  /// 1. Base role definition (strict/friendly tutor persona)
  /// 2. Profile-specific context (name, age, English level)
  /// 3. Personalised lesson/correction rules from the profile
  /// 4. Active lesson mode rules (e.g. Pronunciation Guru, Vocabulary Builder)
  /// 5. A summary of the previous session (if available)
  /// 6. Next focus area from previous session analysis
  String buildSystemPrompt(
    Profile profile, {
    String? previousSessionSummary,
    String? lessonModePrompt,
  }) {
    final buffer = StringBuffer();

    // [1] Base role
    buffer.writeln(_baseSystemRole);

    // [2] Profile data
    buffer.writeln('LEARNER PROFILE:');
    buffer.writeln('- Name: ${profile.name}');
    buffer.writeln('- Age: ${profile.age} years old');
    buffer.writeln('- English Level: ${profile.englishLevel}');
    buffer.writeln();

    // [3] Profile-specific rules
    buffer.writeln('PERSONALISED TEACHING RULES:');
    buffer.writeln(profile.systemPromptRules);
    buffer.writeln();

    // [4] Active lesson mode rules
    if (lessonModePrompt != null && lessonModePrompt.isNotEmpty) {
      buffer.writeln('ACTIVE LESSON MODE RULES:');
      buffer.writeln(lessonModePrompt);
      buffer.writeln();
    }

    // [5] Correction protocol (always applied)
    buffer.writeln(_correctionProtocol);

    // [6] Previous session context
    if (previousSessionSummary != null && previousSessionSummary.isNotEmpty) {
      buffer.writeln('PREVIOUS SESSION SUMMARY:');
      buffer.writeln(previousSessionSummary);
      buffer.writeln(
        'Use this context to continue from where you left off when relevant.',
      );
      buffer.writeln();
    }

    // [7] Next focus area from previous session analysis
    if (profile.nextFocus.isNotEmpty) {
      buffer.writeln('PRIORITY FOCUS FOR THIS SESSION:');
      buffer.writeln(profile.nextFocus);
      buffer.writeln(
        'Incorporate this focus area naturally into the session when appropriate.',
      );
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Converts a list of [ChatMessage]s into Gemini [Content] objects.
  List<Content> _buildHistory(List<ChatMessage> history) {
    return history.map((msg) {
      final role = msg.role == 'model' ? 'model' : 'user';
      return Content(role, [TextPart(msg.text)]);
    }).toList();
  }

  /// Sends [userMessage] to the Gemini model, using the provided [profile] and
  /// optional [previousSessionSummary] to build the system prompt.
  ///
  /// [chatHistory] contains the turns that occurred in the current session so
  /// that the model maintains conversational context.
  ///
  /// Returns the model's text response, or throws a [GeminiServiceException] on
  /// failure.
  Future<String> sendMessage({
    required String userMessage,
    required Profile profile,
    required List<ChatMessage> chatHistory,
    String? previousSessionSummary,
    String? lessonModePrompt,
  }) async {
    final systemPrompt = buildSystemPrompt(
      profile,
      previousSessionSummary: previousSessionSummary,
      lessonModePrompt: lessonModePrompt,
    );

    final history = _buildHistory(chatHistory);

    final chat = _model.startChat(
      history: history,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 512,
      ),
      systemInstruction: Content.system(systemPrompt),
    );

    try {
      final response = await chat.sendMessage(Content.text(userMessage));
      final text = response.text;
      if (text == null || text.isEmpty) {
        throw GeminiServiceException('Received an empty response from the AI.');
      }
      return text;
    } on GenerativeAIException catch (e) {
      throw GeminiServiceException('Gemini API error: ${e.message}');
    }
  }

  /// Generates a concise summary of the session chat history for storage as
  /// `auto_summary` in Firestore.  This summary is fed back as [previousSessionSummary]
  /// in future sessions to provide continuity.
  Future<String> generateSessionSummary({
    required Profile profile,
    required List<ChatMessage> chatHistory,
  }) async {
    if (chatHistory.isEmpty) return '';

    final historyText = chatHistory
        .map((m) => '${m.role == 'model' ? 'Tutor' : profile.name}: ${m.text}')
        .join('\n');

    const summaryInstruction = '''
Summarise the following English tutoring session in 3-5 sentences.
Focus on: topics covered, mistakes made, corrections given, and the learner's progress.
Be specific so the tutor can continue effectively in the next session.
''';

    final prompt = '$summaryInstruction\n\nSESSION TRANSCRIPT:\n$historyText';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } on GenerativeAIException catch (e) {
      throw GeminiServiceException(
          'Failed to generate session summary: ${e.message}');
    }
  }

  /// Analyzes the session chat history and returns a structured JSON response
  /// with 'mistakes', 'vocabulary', and 'next_focus' keys.
  ///
  /// This is sent as a background, non-vocal prompt to Gemini after the user
  /// ends a session. The raw JSON string response is returned for parsing by
  /// the caller.
  Future<String> analyzeSession({
    required Profile profile,
    required List<ChatMessage> chatHistory,
  }) async {
    if (chatHistory.isEmpty) return '{}';

    final historyText = chatHistory
        .map((m) => '${m.role == 'model' ? 'Tutor' : profile.name}: ${m.text}')
        .join('\n');

    const analysisInstruction = '''
Analyze this English learning conversation. Output a JSON format with 3 keys: 'mistakes' (array of grammar/pronunciation errors made by the user), 'vocabulary' (array of new words used/taught), and 'next_focus' (a short string recommending what the tutor should focus on next time).
Respond ONLY with valid JSON, no additional text or markdown formatting.
''';

    final prompt = '$analysisInstruction\n\nSESSION TRANSCRIPT:\n$historyText';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? '{}';
    } on GenerativeAIException catch (e) {
      throw GeminiServiceException(
          'Failed to analyze session: ${e.message}');
    }
  }
}

/// Thrown when the [GeminiService] encounters an error communicating with the
/// Gemini API or processing its response.
class GeminiServiceException implements Exception {
  final String message;
  const GeminiServiceException(this.message);

  @override
  String toString() => 'GeminiServiceException: $message';
}
