import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/profile.dart';
import '../models/session_summary.dart';
import '../models/word_item.dart';

/// Handles Firestore operations for session summaries and user profile context.
///
/// This service is responsible for saving structured session analysis data
/// and updating user profiles with the 'next_focus' recommendation so it
/// can be injected into the Prompt Orchestrator for the next session.
class FirebaseService {
  final FirebaseFirestore _db;

  FirebaseService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Profile Seeding
  // ---------------------------------------------------------------------------

  /// Ensures default profiles exist for the given anonymous [userId].
  ///
  /// Queries the `profiles` collection for documents belonging to this user.
  /// If none are found, creates two default profiles (Wife & Daughter) with
  /// the appropriate system prompt rules and English level.
  Future<void> ensureDefaultProfilesExist(String userId) async {
    final snapshot = await _db
        .collection('profiles')
        .where('user_id', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) return;

    final defaults = [
      Profile.defaultAdult(userId: userId),
      Profile.defaultChild(userId: userId),
    ];

    for (final profile in defaults) {
      await _db
          .collection('profiles')
          .doc(profile.id)
          .set(profile.toFirestore());
    }
  }

  /// Fetches all profiles belonging to the given [userId].
  Future<List<Profile>> getProfilesForUser(String userId) async {
    final snapshot = await _db
        .collection('profiles')
        .where('user_id', isEqualTo: userId)
        .get();
    return snapshot.docs.map(Profile.fromFirestore).toList();
  }

  // ---------------------------------------------------------------------------
  // Session Summaries
  // ---------------------------------------------------------------------------

  /// Saves a structured [SessionSummary] to the session document in Firestore.
  ///
  /// The summary includes parsed mistakes, vocabulary, and next_focus
  /// along with a timestamp and user_id.
  Future<void> saveSessionSummary({
    required String sessionId,
    required String userId,
    required SessionSummary summary,
  }) async {
    await _db.collection('sessions').doc(sessionId).update({
      'session_summary': summary.toMap(),
      'summary_timestamp': FieldValue.serverTimestamp(),
      'user_id': userId,
    });
  }

  // ---------------------------------------------------------------------------
  // User Profile Context
  // ---------------------------------------------------------------------------

  /// Updates the user's profile document with the 'next_focus' recommendation.
  ///
  /// This string is injected into the Prompt Orchestrator for the *next* time
  /// the user opens the app, ensuring continuity across sessions.
  Future<void> updateUserProfileContext({
    required String profileId,
    required String nextFocus,
  }) async {
    await _db.collection('profiles').doc(profileId).update({
      'next_focus': nextFocus,
    });
  }

  /// Updates a full profile document in Firestore.
  ///
  /// Used by the Profile Editor to persist changes to english level,
  /// system prompt rules, and other editable metadata.
  Future<void> updateProfile(Profile profile) async {
    await _db.collection('profiles').doc(profile.id).set(profile.toFirestore());
  }

  // ---------------------------------------------------------------------------
  // Word Bank
  // ---------------------------------------------------------------------------

  /// Syncs vocabulary and mistakes from a [SessionSummary] into the Word Bank.
  ///
  /// Iterates through the `vocabulary` and `mistakes` arrays, creating a
  /// [WordItem] for each. Duplicates (same text, same profile) are skipped.
  Future<void> syncToWordBank({
    required String userId,
    required String profileId,
    required SessionSummary summary,
  }) async {
    final wordBankRef = _db
        .collection('profiles')
        .doc(profileId)
        .collection('word_bank');

    // Fetch existing texts for duplicate prevention.
    final existing = await wordBankRef.get();
    final existingTexts = existing.docs
        .map((doc) => (doc.data()['text'] as String? ?? '').toLowerCase())
        .toSet();

    // Save vocabulary items.
    for (final word in summary.vocabulary) {
      if (word.isEmpty) continue;
      if (existingTexts.contains(word.toLowerCase())) continue;

      final item = WordItem(
        id: '', // Firestore will auto-generate
        text: word,
        type: WordItemType.vocabulary,
        createdAt: DateTime.now(),
      );
      await wordBankRef.add(item.toFirestore());
      existingTexts.add(word.toLowerCase());
    }

    // Save mistake items.
    for (final mistake in summary.mistakes) {
      if (mistake.isEmpty) continue;
      if (existingTexts.contains(mistake.toLowerCase())) continue;

      final item = WordItem(
        id: '',
        text: mistake,
        type: WordItemType.mistake,
        createdAt: DateTime.now(),
      );
      await wordBankRef.add(item.toFirestore());
      existingTexts.add(mistake.toLowerCase());
    }
  }

  /// Fetches all [WordItem]s from the Word Bank for the given [profileId].
  Future<List<WordItem>> getWordBank({required String profileId}) async {
    final snapshot = await _db
        .collection('profiles')
        .doc(profileId)
        .collection('word_bank')
        .orderBy('created_at', descending: true)
        .get();

    return snapshot.docs.map(WordItem.fromFirestore).toList();
  }

  /// Fetches the top [limit] "not yet mastered" words for reinforcement.
  Future<List<WordItem>> getUnmasteredWords({
    required String profileId,
    int limit = 10,
  }) async {
    final snapshot = await _db
        .collection('profiles')
        .doc(profileId)
        .collection('word_bank')
        .where('is_mastered', isEqualTo: false)
        .limit(limit)
        .get();

    return snapshot.docs.map(WordItem.fromFirestore).toList();
  }

  /// Toggles the `isMastered` field on a Word Bank item.
  Future<void> toggleWordMastered({
    required String profileId,
    required String wordId,
    required bool isMastered,
  }) async {
    await _db
        .collection('profiles')
        .doc(profileId)
        .collection('word_bank')
        .doc(wordId)
        .update({'is_mastered': isMastered});
  }
}
