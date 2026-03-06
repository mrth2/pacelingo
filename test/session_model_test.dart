import 'package:flutter_test/flutter_test.dart';
import 'package:pacelingo/models/session.dart';

void main() {
  group('ChatMessage', () {
    test('toMap and fromMap round-trip preserves role and text', () {
      final now = DateTime(2024, 6, 1, 10, 30);
      final original = ChatMessage(role: 'user', text: 'Hello!', timestamp: now);
      final map = original.toMap();
      final restored = ChatMessage.fromMap(map);

      expect(restored.role, original.role);
      expect(restored.text, original.text);
    });

    test('fromMap defaults to user role when role is missing', () {
      final msg = ChatMessage.fromMap({'text': 'Hi'});
      expect(msg.role, 'user');
    });

    test('fromMap defaults to empty text when text is missing', () {
      final msg = ChatMessage.fromMap({'role': 'model'});
      expect(msg.text, '');
    });
  });

  group('Session model', () {
    test('copyWith updates only specified fields', () {
      final original = Session(
        id: 'session-1',
        userId: 'user-abc',
        profileId: 'daughter',
        date: DateTime(2024, 1, 1),
        chatHistory: [],
        autoSummary: 'Worked on vocabulary.',
      );

      final updated = original.copyWith(autoSummary: 'Updated summary.');
      expect(updated.autoSummary, 'Updated summary.');
      expect(updated.id, original.id);
      expect(updated.userId, original.userId);
    });

    test('toFirestore includes all required fields', () {
      final session = Session(
        id: 'test-id',
        userId: 'u1',
        profileId: 'wife',
        date: DateTime.now(),
        chatHistory: [
          ChatMessage(
            role: 'user',
            text: 'Hi',
            timestamp: DateTime.now(),
          ),
        ],
        autoSummary: 'Summary here',
      );

      final map = session.toFirestore();
      expect(map['user_id'], 'u1');
      expect(map['profile_id'], 'wife');
      expect(map['auto_summary'], 'Summary here');
      expect((map['chat_history'] as List).length, 1);
    });
  });
}
