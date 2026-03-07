import 'package:flutter_test/flutter_test.dart';
import 'package:pacelingo/models/session_summary.dart';

void main() {
  group('SessionSummary – JSON parsing', () {
    test('parses valid JSON response correctly', () {
      const raw = '''
{
  "mistakes": ["Used 'goed' instead of 'went'", "Confused 'their' and 'there'"],
  "vocabulary": ["eloquent", "ambiguous", "persevere"],
  "next_focus": "Practice irregular past tense verbs."
}
''';
      final summary = SessionSummary.fromGeminiResponse(raw);

      expect(summary.mistakes.length, 2);
      expect(summary.mistakes[0], contains('goed'));
      expect(summary.vocabulary.length, 3);
      expect(summary.vocabulary, contains('eloquent'));
      expect(summary.nextFocus, 'Practice irregular past tense verbs.');
    });

    test('parses JSON wrapped in markdown code fences', () {
      const raw = '''
```json
{
  "mistakes": ["Said 'more better'"],
  "vocabulary": ["furthermore"],
  "next_focus": "Work on comparatives."
}
```
''';
      final summary = SessionSummary.fromGeminiResponse(raw);

      expect(summary.mistakes.length, 1);
      expect(summary.vocabulary.length, 1);
      expect(summary.nextFocus, 'Work on comparatives.');
    });

    test('returns empty summary for completely invalid response', () {
      const raw = 'This is not JSON at all, just some random text.';
      final summary = SessionSummary.fromGeminiResponse(raw);

      expect(summary.mistakes, isEmpty);
      expect(summary.vocabulary, isEmpty);
      expect(summary.nextFocus, 'Continue practising.');
    });

    test('handles missing keys with defaults', () {
      const raw = '{"mistakes": ["error 1"]}';
      final summary = SessionSummary.fromGeminiResponse(raw);

      expect(summary.mistakes.length, 1);
      expect(summary.vocabulary, isEmpty);
      expect(summary.nextFocus, 'Continue practising.');
    });

    test('handles empty arrays correctly', () {
      const raw =
          '{"mistakes": [], "vocabulary": [], "next_focus": "Keep it up!"}';
      final summary = SessionSummary.fromGeminiResponse(raw);

      expect(summary.mistakes, isEmpty);
      expect(summary.vocabulary, isEmpty);
      expect(summary.nextFocus, 'Keep it up!');
    });

    test('filters out null/empty entries in arrays', () {
      const raw =
          '{"mistakes": ["error 1", null, "", "error 2"], "vocabulary": [], "next_focus": "Review."}';
      final summary = SessionSummary.fromGeminiResponse(raw);

      expect(summary.mistakes.length, 2);
      expect(summary.mistakes[0], 'error 1');
      expect(summary.mistakes[1], 'error 2');
    });

    test('handles non-string values in arrays gracefully', () {
      const raw =
          '{"mistakes": [1, true, "real error"], "vocabulary": [42], "next_focus": "Numbers."}';
      final summary = SessionSummary.fromGeminiResponse(raw);

      expect(summary.mistakes.length, 3);
      expect(summary.mistakes, contains('real error'));
      expect(summary.vocabulary.length, 1);
    });
  });

  group('SessionSummary – toMap / fromMap', () {
    test('round-trip preserves data', () {
      const original = SessionSummary(
        mistakes: ['Used wrong tense', 'Article missing'],
        vocabulary: ['resilient', 'profound'],
        nextFocus: 'Focus on articles.',
      );

      final map = original.toMap();
      final restored = SessionSummary.fromMap(map);

      expect(restored.mistakes, original.mistakes);
      expect(restored.vocabulary, original.vocabulary);
      expect(restored.nextFocus, original.nextFocus);
    });

    test('fromMap handles missing keys', () {
      final summary = SessionSummary.fromMap({});

      expect(summary.mistakes, isEmpty);
      expect(summary.vocabulary, isEmpty);
      expect(summary.nextFocus, 'Continue practising.');
    });
  });

  group('SessionSummary.empty', () {
    test('creates an empty summary with default values', () {
      const summary = SessionSummary.empty();

      expect(summary.mistakes, isEmpty);
      expect(summary.vocabulary, isEmpty);
      expect(summary.nextFocus, 'Continue practising.');
    });
  });
}
