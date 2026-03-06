import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/profile.dart';
import '../models/session.dart';

/// Provides CRUD operations for the `profiles` and `sessions` Firestore
/// collections.
class FirestoreService {
  final FirebaseFirestore _db;
  static const _uuid = Uuid();

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // Profiles
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _profilesRef =>
      _db.collection('profiles');

  /// Returns all profiles as a stream for real-time updates.
  Stream<List<Profile>> profilesStream() {
    return _profilesRef.snapshots().map(
          (snapshot) => snapshot.docs.map(Profile.fromFirestore).toList(),
        );
  }

  /// Fetches all profiles once.
  Future<List<Profile>> getProfiles() async {
    final snapshot = await _profilesRef.get();
    return snapshot.docs.map(Profile.fromFirestore).toList();
  }

  /// Creates or overwrites a profile document identified by [profile.id].
  Future<void> saveProfile(Profile profile) async {
    await _profilesRef.doc(profile.id).set(profile.toFirestore());
  }

  /// Seeds default profiles if the collection is empty.
  Future<void> seedDefaultProfilesIfEmpty() async {
    final existing = await getProfiles();
    if (existing.isNotEmpty) return;

    final defaults = [Profile.defaultAdult(), Profile.defaultChild()];
    for (final profile in defaults) {
      await saveProfile(profile);
    }
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _db.collection('sessions');

  /// Fetches the most recent session for the given [userId] and [profileId].
  Future<Session?> getLastSession(
      {required String userId, required String profileId}) async {
    final snapshot = await _sessionsRef
        .where('user_id', isEqualTo: userId)
        .where('profile_id', isEqualTo: profileId)
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Session.fromFirestore(snapshot.docs.first);
  }

  /// Creates a new session document and returns its generated ID.
  Future<String> createSession({
    required String userId,
    required String profileId,
  }) async {
    final id = _uuid.v4();
    final session = Session(
      id: id,
      userId: userId,
      profileId: profileId,
      date: DateTime.now(),
      chatHistory: [],
    );
    await _sessionsRef.doc(id).set(session.toFirestore());
    return id;
  }

  /// Appends a [ChatMessage] to an existing session's chat history.
  Future<void> appendMessage({
    required String sessionId,
    required ChatMessage message,
  }) async {
    await _sessionsRef.doc(sessionId).update({
      'chat_history': FieldValue.arrayUnion([message.toMap()]),
    });
  }

  /// Updates the [autoSummary] field of a session.
  Future<void> updateSessionSummary({
    required String sessionId,
    required String summary,
  }) async {
    await _sessionsRef.doc(sessionId).update({'auto_summary': summary});
  }
}
