import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../services/firebase_service.dart';
import '../services/firestore_service.dart';

/// Manages the available user profiles and the currently selected profile.
class ProfileProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final FirebaseService _firebaseService;

  List<Profile> _profiles = [];
  Profile? _selectedProfile;
  bool _isLoading = false;
  String? _error;

  ProfileProvider({
    FirestoreService? firestoreService,
    FirebaseService? firebaseService,
  })  : _firestoreService = firestoreService ?? FirestoreService(),
        _firebaseService = firebaseService ?? FirebaseService();

  List<Profile> get profiles => List.unmodifiable(_profiles);
  Profile? get selectedProfile => _selectedProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads profiles from Firestore for the given [userId], seeding defaults
  /// if the collection has no data for this user.
  Future<void> loadProfiles({String? userId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (userId != null && userId.isNotEmpty) {
        await _firebaseService.ensureDefaultProfilesExist(userId);
        _profiles = await _firebaseService.getProfilesForUser(userId);
      } else {
        await _firestoreService.seedDefaultProfilesIfEmpty();
        _profiles = await _firestoreService.getProfiles();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selects a profile to use for the current tutoring session.
  void selectProfile(Profile profile) {
    _selectedProfile = profile;
    notifyListeners();
  }

  /// Clears the current profile selection (e.g. when returning to the dashboard).
  void clearSelection() {
    _selectedProfile = null;
    notifyListeners();
  }

  /// Updates a profile in Firestore and refreshes the local profiles list.
  Future<void> updateProfile(Profile profile) async {
    try {
      await _firebaseService.updateProfile(profile);

      // Refresh the local list by replacing the updated profile.
      final index = _profiles.indexWhere((p) => p.id == profile.id);
      if (index != -1) {
        _profiles = List<Profile>.from(_profiles)..[index] = profile;
      }

      // Update selected profile if it matches.
      if (_selectedProfile?.id == profile.id) {
        _selectedProfile = profile;
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
