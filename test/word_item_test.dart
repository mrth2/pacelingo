import 'package:flutter_test/flutter_test.dart';
import 'package:pacelingo/models/word_item.dart';

void main() {
  group('WordItem model', () {
    test('toFirestore includes all fields', () {
      final now = DateTime(2024, 6, 1, 10, 30);
      final item = WordItem(
        id: 'test-id',
        text: 'eloquent',
        definition: 'fluent or persuasive in speaking',
        exampleSentence: 'She gave an eloquent speech.',
        type: WordItemType.vocabulary,
        createdAt: now,
        isMastered: false,
      );

      final map = item.toFirestore();
      expect(map['text'], 'eloquent');
      expect(map['definition'], 'fluent or persuasive in speaking');
      expect(map['example_sentence'], 'She gave an eloquent speech.');
      expect(map['type'], 'vocabulary');
      expect(map['is_mastered'], false);
    });

    test('toFirestore sets type to mistake for mistake items', () {
      final item = WordItem(
        id: 'err-1',
        text: "Used 'goed' instead of 'went'",
        type: WordItemType.mistake,
        createdAt: DateTime.now(),
      );

      final map = item.toFirestore();
      expect(map['type'], 'mistake');
    });

    test('fromMap creates vocabulary item correctly', () {
      final map = <String, dynamic>{
        'text': 'persevere',
        'definition': 'continue despite difficulty',
        'example_sentence': 'You must persevere.',
        'type': 'vocabulary',
        'created_at': DateTime(2024, 1, 1),
        'is_mastered': true,
      };

      final item = WordItem.fromMap('doc-1', map);
      expect(item.id, 'doc-1');
      expect(item.text, 'persevere');
      expect(item.definition, 'continue despite difficulty');
      expect(item.type, WordItemType.vocabulary);
      expect(item.isMastered, true);
    });

    test('fromMap creates mistake item correctly', () {
      final map = <String, dynamic>{
        'text': "Confused 'their' and 'there'",
        'type': 'mistake',
        'created_at': DateTime(2024, 1, 1),
        'is_mastered': false,
      };

      final item = WordItem.fromMap('doc-2', map);
      expect(item.type, WordItemType.mistake);
      expect(item.isMastered, false);
    });

    test('fromMap defaults to vocabulary when type is missing', () {
      final item = WordItem.fromMap('doc-3', {'text': 'hello'});
      expect(item.type, WordItemType.vocabulary);
    });

    test('fromMap defaults to false for isMastered when missing', () {
      final item = WordItem.fromMap('doc-4', {'text': 'test'});
      expect(item.isMastered, false);
    });

    test('copyWith updates only specified fields', () {
      final item = WordItem(
        id: 'id-1',
        text: 'resilient',
        definition: 'able to recover quickly',
        type: WordItemType.vocabulary,
        createdAt: DateTime(2024, 1, 1),
        isMastered: false,
      );

      final updated = item.copyWith(isMastered: true);
      expect(updated.isMastered, true);
      expect(updated.text, 'resilient');
      expect(updated.definition, 'able to recover quickly');
      expect(updated.id, 'id-1');
      expect(updated.type, WordItemType.vocabulary);
    });

    test('copyWith updates text and type', () {
      final item = WordItem(
        id: 'id-2',
        text: 'original',
        type: WordItemType.vocabulary,
        createdAt: DateTime.now(),
      );

      final updated = item.copyWith(
        text: 'updated',
        type: WordItemType.mistake,
      );
      expect(updated.text, 'updated');
      expect(updated.type, WordItemType.mistake);
    });

    test('default values for optional fields', () {
      final item = WordItem(
        id: 'id-3',
        text: 'simple',
        type: WordItemType.vocabulary,
        createdAt: DateTime.now(),
      );

      expect(item.definition, '');
      expect(item.exampleSentence, '');
      expect(item.isMastered, false);
    });
  });
}
