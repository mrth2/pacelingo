import 'package:firebase_auth/firebase_auth.dart';

/// Manages Firebase Authentication, using anonymous sign-in so users can
/// start using the app immediately without creating an account.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// The currently signed-in user, or `null` if not authenticated.
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in anonymously.  Safe to call even if the user is already signed in
  /// — Firebase returns the existing anonymous credential in that case.
  Future<UserCredential> signInAnonymously() => _auth.signInAnonymously();

  /// Signs out the current user.
  Future<void> signOut() => _auth.signOut();
}
