import '../entities/user_profile.dart';

abstract interface class AuthRepository {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;

  Future<UserProfile> signUpWithEmail(String email, String password, String name);
  Future<UserProfile> signInWithEmail(String email, String password);
  Future<UserProfile> signInWithGoogle();
  Future<UserProfile> signInWithApple();
  Future<void> signOut();
  Future<void> updateProfile({String? name, String? currency});
  Future<void> sendPasswordReset(String email);
}
