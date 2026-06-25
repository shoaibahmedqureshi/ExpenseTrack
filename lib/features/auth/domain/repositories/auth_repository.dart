import '../entities/user_profile.dart';

abstract interface class AuthRepository {
  Stream<UserProfile?> get authStateChanges;

  /// Emits whenever Supabase reports the session came from a password
  /// recovery link, so the UI can route to the set-new-password screen
  /// instead of treating it as a normal sign-in.
  Stream<void> get passwordRecoveryRequested;

  UserProfile? get currentUser;

  Future<UserProfile> signUpWithEmail(String email, String password, String name);
  Future<UserProfile> signInWithEmail(String email, String password);
  Future<UserProfile> signInWithGoogle();
  Future<void> signOut();
  Future<void> updateProfile({String? name, String? currency});
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
}
