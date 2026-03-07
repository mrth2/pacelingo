import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/session_summary.dart';

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
}
