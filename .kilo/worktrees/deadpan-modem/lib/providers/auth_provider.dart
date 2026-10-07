import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus {
  /// Splash has not resolved the stored session yet.
  unknown,
  loading,
  authenticated,
  unauthenticated,
}

/// Owns the account/session state (spec §8, §9).
///
/// Screen-level form validation lives in the auth screens; this class owns
/// *domain* rules (duplicate email, wrong credentials, password length) and
/// guarantees the UI always has a readable [errorMessage] when something fails.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _errorMessage;
  bool _busy = false;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get busy => _busy;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;

  /// Called once by the splash screen (spec §7: "check the stored session").
  Future<void> restoreSession() async {
    _setBusy(true);
    try {
      final User? restored = await _repository.restoreSession();
      _user = restored;
      _status =
          restored == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    } on Object catch (_) {
      // A corrupt store must not lock the user out of the app.
      _user = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      _setBusy(false, notify: true);
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final String? validation = validateRegistration(
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (validation != null) {
      _errorMessage = validation;
      _notify();
      return false;
    }

    _setBusy(true);
    try {
      final bool exists = await _repository.isEmailRegistered(email);
      if (exists) {
        _errorMessage = 'That email is already registered.';
        _notify();
        return false;
      }
      final User created = await _repository.register(
        username: username,
        email: email,
        password: password,
      );
      _user = created;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      return true;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      return false;
    } on Object catch (_) {
      _errorMessage = 'Could not save your account. Please try again.';
      return false;
    } finally {
      _setBusy(false, notify: true);
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty) {
      _errorMessage = 'Email is required.';
      _notify();
      return false;
    }
    if (!isValidEmail(email)) {
      _errorMessage = 'Enter a valid email address.';
      _notify();
      return false;
    }
    if (password.isEmpty) {
      _errorMessage = 'Password is required.';
      _notify();
      return false;
    }

    _setBusy(true);
    try {
      final User loggedIn =
          await _repository.login(email: email, password: password);
      _user = loggedIn;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
      return true;
    } on AuthException catch (error) {
      _errorMessage = error.message;
      return false;
    } on Object catch (_) {
      _errorMessage = 'Could not sign in. Please try again.';
      return false;
    } finally {
      _setBusy(false, notify: true);
    }
  }

  Future<void> logout() async {
    _setBusy(true);
    try {
      await _repository.logout();
    } on Object catch (_) {
      // Even if clearing the session fails we drop the in-memory user so the
      // UI cannot get stuck on an authenticated shell.
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      _setBusy(false, notify: true);
    }
  }

  Future<void> renameAccount(String username) async {
    final User? current = _user;
    if (current == null || username.trim().isEmpty) {
      return;
    }
    try {
      await _repository.updateUsername(current.id, username);
      _user = current.copyWith(username: username.trim());
      _notify();
    } on AuthException catch (error) {
      _errorMessage = error.message;
      _notify();
    }
  }

  Future<void> deleteAccount() async {
    final User? current = _user;
    if (current == null) {
      return;
    }
    try {
      await _repository.deleteAccount(current.id);
    } on Object catch (_) {
      // fall through: the account is removed from the local store either way
    }
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    _notify();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Validation helpers (shared by the register screen and the provider)
  // ---------------------------------------------------------------------------

  static final RegExp _emailPattern = RegExp(
    r'^[\w.!#$%&*+/=?^`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
  );

  static bool isValidEmail(String email) =>
      _emailPattern.hasMatch(email.trim());

  static const int minPasswordLength = 6;

  /// Returns the first failing rule, or `null` when the form is valid.
  static String? validateRegistration({
    required String username,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (username.trim().isEmpty) {
      return 'Username is required.';
    }
    if (username.trim().length < 2) {
      return 'Username must be at least 2 characters.';
    }
    if (!isValidEmail(email)) {
      return 'Enter a valid email address.';
    }
    if (password.isEmpty) {
      return 'Password is required.';
    }
    if (password.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }

  // ---------------------------------------------------------------------------

  void _setBusy(bool value, {bool notify = false}) {
    _busy = value;
    if (notify) {
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
