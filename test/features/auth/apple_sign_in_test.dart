import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:outlay/features/auth/domain/entities/user_profile.dart';
import 'package:outlay/features/auth/domain/repositories/auth_repository.dart';
import 'package:outlay/features/auth/presentation/providers/auth_provider.dart';
import 'package:outlay/features/auth/presentation/screens/login_screen.dart';
import 'package:outlay/features/auth/presentation/screens/signup_screen.dart';

/// Records whether signInWithApple() was actually invoked, and can be told
/// to throw so tests can exercise the error path without a real Apple
/// sign-in sheet — that's not something a widget/unit test can drive at
/// all, so this is the boundary this app's own code controls.
class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.appleSignInError});
  final Object? appleSignInError;
  bool appleSignInCalled = false;

  @override
  Stream<UserProfile?> get authStateChanges => const Stream.empty();
  @override
  UserProfile? get currentUser => null;
  @override
  Future<UserProfile> signUpWithEmail(String e, String p, String n) async =>
      const UserProfile(id: '1', email: 'a@b.com');
  @override
  Future<UserProfile> signInWithEmail(String e, String p) async =>
      const UserProfile(id: '1', email: 'a@b.com');
  @override
  Future<UserProfile> signInWithGoogle() async =>
      const UserProfile(id: '1', email: 'a@b.com');
  @override
  Future<UserProfile> signInWithApple() async {
    appleSignInCalled = true;
    if (appleSignInError != null) throw appleSignInError!;
    return const UserProfile(id: '1', email: 'a@b.com');
  }

  @override
  Future<void> signOut() async {}
  @override
  Future<void> updateProfile({String? name, String? currency}) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
}

Widget _wrap(Widget child, AuthProvider provider) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>.value(
      value: provider,
      child: child,
    ),
  );
}

void main() {
  group('Continue with Apple button — required by App Store Guideline 4.8 '
      'since Google Sign-In is already offered', () {
    testWidgets('is shown on the login screen on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = AuthProvider(_RecordingAuthRepository());
      addTearDown(provider.dispose);

      await tester.pumpWidget(_wrap(const LoginScreen(), provider));

      expect(find.text('Continue with Apple'), findsOneWidget);
      // Must be reset synchronously before this test body returns — a
      // deferred tearDown()/addTearDown() runs too late, after Flutter's
      // own end-of-test invariant check has already flagged it as still set.
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('is shown on the signup screen on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = AuthProvider(_RecordingAuthRepository());
      addTearDown(provider.dispose);

      await tester.pumpWidget(_wrap(const SignupScreen(), provider));

      expect(find.text('Continue with Apple'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
        'CRITICAL: is hidden on Android on both screens — the native '
        'flow needs a web-based Services ID we have not configured there, '
        'so showing it would just be a dead button', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final provider = AuthProvider(_RecordingAuthRepository());
      addTearDown(provider.dispose);

      await tester.pumpWidget(_wrap(const LoginScreen(), provider));
      expect(find.text('Continue with Apple'), findsNothing);

      await tester.pumpWidget(_wrap(const SignupScreen(), provider));
      expect(find.text('Continue with Apple'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('tapping it on the login screen calls through to sign-in',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final repo = _RecordingAuthRepository();
      final provider = AuthProvider(repo);
      addTearDown(provider.dispose);

      await tester.pumpWidget(_wrap(const LoginScreen(), provider));
      await tester.ensureVisible(find.text('Continue with Apple'));
      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(repo.appleSignInCalled, isTrue);
      expect(provider.error, isNull);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('tapping it on the signup screen calls through to sign-in',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final repo = _RecordingAuthRepository();
      final provider = AuthProvider(repo);
      addTearDown(provider.dispose);

      await tester.pumpWidget(_wrap(const SignupScreen(), provider));
      await tester.ensureVisible(find.text('Continue with Apple'));
      await tester.tap(find.text('Continue with Apple'));
      await tester.pumpAndSettle();

      expect(repo.appleSignInCalled, isTrue);
      expect(provider.error, isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('Apple sign-in error mapping', () {
    test(
        'CRITICAL: a cancelled Apple sign-in ("canceled", American '
        'spelling) gets the same friendly message a cancelled Google '
        'sign-in already gets — the generic raw.contains(\'cancelled\') '
        'check never matches Apple\'s spelling, which would otherwise fall '
        'all the way through to "Something went wrong"', () async {
      final repo = _RecordingAuthRepository(
        appleSignInError: const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'The user canceled the authorization attempt',
        ),
      );
      final provider = AuthProvider(repo);
      addTearDown(provider.dispose);

      await provider.signInWithApple();

      expect(provider.error, 'Sign-in was cancelled.');
    });
  });
}
