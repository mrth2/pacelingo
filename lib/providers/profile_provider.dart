import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../services/firestore_service.dart';

/// Manages the available user profiles and the currently selected profile.
class ProfileProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<Profile> _profiles = [];
  Profile? _selectedProfile;
  bool _isLoading = false;
  String? _error;

  ProfileProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  List<Profile> get profiles => List.unmodifiable(_profiles);
  Profile? get selectedProfile => _selectedProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads profiles from Firestore, seeding defaults if the collection is empty.
  Future<void> loadProfiles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.seedDefaultProfilesIfEmpty();
      _profiles = await _firestoreService.getProfiles();
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
}
