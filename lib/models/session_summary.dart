import 'dart:convert';

/// Represents a structured analysis of a tutoring session, parsed from Gemini's
/// JSON response.
///
/// Contains the learner's mistakes, new vocabulary, and a recommendation for
/// the next session's focus area.
class SessionSummary {
  final List<String> mistakes;
  final List<String> vocabulary;
  final String nextFocus;

  const SessionSummary({
    required this.mistakes,
    required this.vocabulary,
    required this.nextFocus,
  });

  /// Parses a JSON string from Gemini into a [SessionSummary].
  ///
  /// Uses robust parsing with try-catch and fallback defaults if the AI
  /// hallucinates the JSON structure or returns malformed output.
  factory SessionSummary.fromGeminiResponse(String rawResponse) {
    try {
      // Strip markdown code fences if present (e.g. ```json ... ```)
      final cleaned = _stripCodeFences(rawResponse).trim();
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;

      return SessionSummary(
        mistakes: _parseStringList(decoded['mistakes']),
        vocabulary: _parseStringList(decoded['vocabulary']),
        nextFocus: (decoded['next_focus'] as String?) ?? 'Continue practising.',
      );
    } catch (_) {
      // Fallback: return empty summary if parsing fails entirely.
      return const SessionSummary(
        mistakes: [],
        vocabulary: [],
        nextFocus: 'Continue practising.',
      );
    }
  }

  /// Creates an empty summary used as a fallback.
  const SessionSummary.empty()
      : mistakes = const [],
        vocabulary = const [],
        nextFocus = 'Continue practising.';

  /// Converts this summary to a Firestore-compatible map.
  Map<String, dynamic> toMap() => {
        'mistakes': mistakes,
        'vocabulary': vocabulary,
        'next_focus': nextFocus,
      };

  /// Creates a [SessionSummary] from a Firestore map.
  factory SessionSummary.fromMap(Map<String, dynamic> map) {
    return SessionSummary(
      mistakes: _parseStringList(map['mistakes']),
      vocabulary: _parseStringList(map['vocabulary']),
      nextFocus: (map['next_focus'] as String?) ?? 'Continue practising.',
    );
  }

  /// Strips markdown code fences (```json ... ```) from a raw response.
  static String _stripCodeFences(String input) {
    final fencePattern = RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?\s*```');
    final match = fencePattern.firstMatch(input);
    if (match != null) {
      return match.group(1) ?? input;
    }
    return input;
  }

  /// Safely parses a dynamic value into a List<String>.
  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return [];
  }
}
