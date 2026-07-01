import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository) {
    _sub = _repository.authStateChanges.listen(
      (profile) {
        _profile = profile;
        _status = profile != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[AuthProvider] stream error: $e');
        _status = AuthStatus.unauthenticated;
        _error = _friendly(e.toString());
        notifyListeners();
      },
    );
  }

  final AuthRepository _repository;
  StreamSubscription<UserProfile?>? _sub;

  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _profile;
  bool _loading = false;
  String? _error;

  AuthStatus get status => _status;
  UserProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> signUp(String email, String password, String name) =>
      _run(() => _repository.signUpWithEmail(email, password, name));

  Future<void> signIn(String email, String password) =>
      _run(() => _repository.signInWithEmail(email, password));

  Future<void> signInWithGoogle() =>
      _run(() => _repository.signInWithGoogle());

  Future<void> signOut() => _run(() async {
        await _repository.signOut();
        _profile = null;
        _status = AuthStatus.unauthenticated;
      });

  Future<void> updateProfile({String? name, String? currency}) =>
      _run(() async {
        await _repository.updateProfile(name: name, currency: currency);
        if (_profile != null) {
          _profile = _profile!.copyWith(name: name, currency: currency);
        }
      });

  Future<void> sendPasswordReset(String email) =>
      _run(() => _repository.sendPasswordReset(email));

  Future<void> _run(Future<void> Function() fn) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await fn();
    } catch (e) {
      _error = _friendly(e.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _friendly(String raw) {
    debugPrint('[AuthProvider] error: $raw');
    if (raw.contains('Invalid login credentials')) return 'Incorrect email or password.';
    if (raw.contains('User already registered')) return 'An account with this email already exists.';
    if (raw.contains('Email not confirmed')) return 'Please confirm your email before signing in.';
    if (raw.contains('cancelled')) return 'Sign-in was cancelled.';
    if (raw.contains('TimeoutException')) {
      return 'The connection timed out. Check your internet and try again.';
    }
    if (raw.contains('network') || raw.contains('SocketException')) return 'No internet connection.';
    if (raw.contains('does not exist') || raw.contains('relation')) {
      return 'Database not set up. Please run the schema SQL in your Supabase dashboard.';
    }
    // Show raw error in debug so it's easy to diagnose
    if (kDebugMode) return raw;
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
