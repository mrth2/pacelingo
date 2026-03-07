import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user profile stored in the `profiles` Firestore collection.
class Profile {
  final String id;
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
    this.nextFocus = '',
  });

  /// Creates a [Profile] from a Firestore document snapshot.
  factory Profile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Profile(
      id: doc.id,
      name: data['name'] as String? ?? '',
      age: (data['age'] as num?)?.toInt() ?? 0,
      englishLevel: data['english_level'] as String? ?? 'beginner',
      systemPromptRules: data['system_prompt_rules'] as String? ?? '',
      nextFocus: data['next_focus'] as String? ?? '',
    );
  }

  /// Converts this [Profile] to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
        'name': name,
        'age': age,
        'english_level': englishLevel,
        'system_prompt_rules': systemPromptRules,
        'next_focus': nextFocus,
      };

  /// Creates a default profile for a child learner.
  factory Profile.defaultChild() => const Profile(
        id: 'daughter',
        name: 'Daughter',
        age: 11,
        englishLevel: 'intermediate',
        systemPromptRules:
            'Be friendly, encouraging, and patient. Use simple vocabulary. '
            'Correct pronunciation mistakes gently by repeating the correct form '
            'up to 3 times before moving on. Use fun examples and stories.',
      );

  /// Creates a default profile for an adult learner.
  factory Profile.defaultAdult() => const Profile(
        id: 'wife',
        name: 'Wife',
        age: 35,
        englishLevel: 'intermediate',
        systemPromptRules:
            'Be professional yet warm. Focus on practical conversational English. '
            'Correct grammar and pronunciation mistakes precisely. '
            'Provide explanations for corrections when helpful.',
      );

  Profile copyWith({
    String? id,
    String? name,
    int? age,
    String? englishLevel,
    String? systemPromptRules,
    String? nextFocus,
  }) {
    return Profile(
      id: id ?? this.id,
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
