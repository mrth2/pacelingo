import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user profile stored in the `profiles` Firestore collection.
class Profile {
  final String id;
  final String userId;
  final String name;
  final int age;
  final String englishLevel;
  final String systemPromptRules;
  final String nextFocus;

  const Profile({
    required this.id,
    required this.name,
    required this.age,
    required this.englishLevel,
    required this.systemPromptRules,
    this.userId = '',
    this.nextFocus = '',
  });

  /// Creates a [Profile] from a Firestore document snapshot.
  factory Profile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Profile(
      id: doc.id,
      userId: data['user_id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      englishLevel: data['english_level'] as String? ?? 'beginner',
      systemPromptRules: data['system_prompt_rules'] as String? ?? '',
      nextFocus: data['next_focus'] as String? ?? '',
    );
  }

  /// Converts this [Profile] to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
        'user_id': userId,
        'name': name,
        'age': age,
        'english_level': englishLevel,
        'system_prompt_rules': systemPromptRules,
        'next_focus': nextFocus,
      };

  /// Creates a default profile for a child learner.
  factory Profile.defaultChild({String userId = ''}) => Profile(
        id: userId.isEmpty ? 'daughter' : '${userId}_daughter',
        userId: userId,
        name: 'Daughter',
        age: 11,
        englishLevel: 'Beginner/Pre-Intermediate',
        systemPromptRules:
            'Act as a fun, encouraging, and patient English teacher for an '
            '11-year-old girl. Keep sentences short. If she mispronounces, '
            'gently ask her to try again up to 2 times before moving on. '
            'Praise her often.',
      );

  /// Creates a default profile for an adult learner.
  factory Profile.defaultAdult({String userId = ''}) => Profile(
        id: userId.isEmpty ? 'wife' : '${userId}_wife',
        userId: userId,
        name: 'Wife',
        age: 35,
        englishLevel: 'Intermediate',
        systemPromptRules:
            'Act as a professional English tutor. Focus on conversational '
            'fluency, business English, and strict grammar correction. '
            'Be polite but direct.',
      );

  Profile copyWith({
    String? id,
    String? userId,
    String? name,
    int? age,
    String? englishLevel,
    String? systemPromptRules,
    String? nextFocus,
  }) {
    return Profile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      age: age ?? this.age,
      englishLevel: englishLevel ?? this.englishLevel,
      systemPromptRules: systemPromptRules ?? this.systemPromptRules,
      nextFocus: nextFocus ?? this.nextFocus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Profile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
