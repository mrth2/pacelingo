import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single turn in a conversation.
class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      role: map['role'] as String? ?? 'user',
      text: map['text'] as String? ?? '',
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': role,
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

/// Represents a tutoring session stored in the `sessions` Firestore collection.
class Session {
  final String id;
  final String userId;
  final String profileId;
  final DateTime date;
  final List<ChatMessage> chatHistory;
  final String autoSummary;

  const Session({
    required this.id,
    required this.userId,
    required this.profileId,
    required this.date,
    required this.chatHistory,
    this.autoSummary = '',
  });

  /// Creates a [Session] from a Firestore document snapshot.
  factory Session.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawHistory = data['chat_history'] as List<dynamic>? ?? [];
    return Session(
      id: doc.id,
      userId: data['user_id'] as String? ?? '',
      profileId: data['profile_id'] as String? ?? '',
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      chatHistory: rawHistory
          .map((e) => ChatMessage.fromMap(e as Map<String, dynamic>))
          .toList(),
      autoSummary: data['auto_summary'] as String? ?? '',
    );
  }

  /// Converts this [Session] to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
        'user_id': userId,
        'profile_id': profileId,
        'date': Timestamp.fromDate(date),
        'chat_history': chatHistory.map((m) => m.toMap()).toList(),
        'auto_summary': autoSummary,
      };

  Session copyWith({
    String? id,
    String? userId,
    String? profileId,
    DateTime? date,
    List<ChatMessage>? chatHistory,
    String? autoSummary,
  }) {
    return Session(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      profileId: profileId ?? this.profileId,
      date: date ?? this.date,
      chatHistory: chatHistory ?? this.chatHistory,
      autoSummary: autoSummary ?? this.autoSummary,
    );
  }
}
