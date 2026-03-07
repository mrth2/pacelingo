import 'package:cloud_firestore/cloud_firestore.dart';

/// The type of a word bank entry.
enum WordItemType {
  vocabulary,
  mistake,
}

/// Represents a single entry in the user's Word Bank.
///
/// A [WordItem] can be either a **vocabulary** word learned during a session
/// or a **mistake** that the learner made and should review.
class WordItem {
  final String id;
  final String text;
  final String definition;
  final String exampleSentence;
  final WordItemType type;
  final DateTime createdAt;
  final bool isMastered;

  const WordItem({
    required this.id,
    required this.text,
    this.definition = '',
    this.exampleSentence = '',
    required this.type,
    required this.createdAt,
    this.isMastered = false,
  });

  /// Creates a [WordItem] from a Firestore document snapshot.
  factory WordItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WordItem(
      id: doc.id,
      text: data['text'] as String? ?? '',
      definition: data['definition'] as String? ?? '',
      exampleSentence: data['example_sentence'] as String? ?? '',
      type: (data['type'] as String?) == 'mistake'
          ? WordItemType.mistake
          : WordItemType.vocabulary,
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      isMastered: data['is_mastered'] as bool? ?? false,
    );
  }

  /// Creates a [WordItem] from a Firestore-compatible map (with an id).
  factory WordItem.fromMap(String id, Map<String, dynamic> map) {
    return WordItem(
      id: id,
      text: map['text'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      exampleSentence: map['example_sentence'] as String? ?? '',
      type: (map['type'] as String?) == 'mistake'
          ? WordItemType.mistake
          : WordItemType.vocabulary,
      createdAt: map['created_at'] is Timestamp
          ? (map['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      isMastered: map['is_mastered'] as bool? ?? false,
    );
  }

  /// Converts this [WordItem] to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
        'text': text,
        'definition': definition,
        'example_sentence': exampleSentence,
        'type': type == WordItemType.mistake ? 'mistake' : 'vocabulary',
        'created_at': Timestamp.fromDate(createdAt),
        'is_mastered': isMastered,
      };

  WordItem copyWith({
    String? id,
    String? text,
    String? definition,
    String? exampleSentence,
    WordItemType? type,
    DateTime? createdAt,
    bool? isMastered,
  }) {
    return WordItem(
      id: id ?? this.id,
      text: text ?? this.text,
      definition: definition ?? this.definition,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isMastered: isMastered ?? this.isMastered,
    );
  }
}
