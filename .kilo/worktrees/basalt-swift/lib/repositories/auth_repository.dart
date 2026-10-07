import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/user.dart';
import '../services/storage_service.dart';

/// Raised by [AuthRepository] for every expected failure (duplicate email,
/// bad credentials, ...). The message is safe to show in a SnackBar/dialog.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Local-only account storage and session handling (spec §8, §9).
///
/// Passwords are never persisted. Each account stores a random 16-byte salt and
/// a SHA-256 digest derived from `salt + password`, stretched over [_iterations]
/// rounds. This is deliberately a *school project* scheme — it prevents casual
/// plaintext reads, but it is not a substitute for server-side authentication
/// with a slow KDF (bcrypt/Argon2/scrypt).
class AuthRepository {
  AuthRepository(this._storage, {Random? random})
      : _random = random ?? Random.secure();

  static const int _iterations = 2048;

  final StorageService _storage;
  final Random _random;

  // ---------------------------------------------------------------------------
  // Password hashing
  // ---------------------------------------------------------------------------

  String _newSalt() {
    final List<int> bytes =
        List<int>.generate(16, (_) => _random.nextInt(256), growable: false);
    return base64Url.encode(bytes);
  }

  static String _hash(String salt, String password) {
    final List<int> saltBytes = utf8.encode(salt);
    final List<int> passwordBytes = utf8.encode(password);
    List<int> digest = sha256.convert(<int>[...saltBytes, ...passwordBytes]).bytes;
    for (int round = 1; round < _iterations; round++) {
      digest = sha256.convert(<int>[...digest, ...saltBytes, ...passwordBytes]).bytes;
    }
    return base64Url.encode(digest);
  }

  /// Exposed for tests: derives the digest for a salt/password pair.
  // ignore: non_constant_identifier_names
  static String hashForTesting(String salt, String password) =>
      _hash(salt, password);

  /// Exposed for tests: verifies a candidate password against a stored digest.
  static bool verifyPassword({
    required String salt,
    required String passwordHash,
    required String password,
  }) {
    return _hash(salt, password) == passwordHash;
  }

  // ---------------------------------------------------------------------------
  // Account store
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _readUsers() async {
    final Map<String, dynamic>? raw =
        await _storage.readJsonObject(StorageService.keyUsers);
    if (raw == null) {
      return <String, dynamic>{};
    }
    final Object? accounts = raw['accounts'];
    if (accounts is Map<String, dynamic>) {
      return accounts;
    }
    if (accounts is List<dynamic>) {
      // Tolerate the legacy starter format: a flat {email: {...}} map.
      final Map<String, dynamic> rebuilt = <String, dynamic>{};
      for (final dynamic entry in accounts) {
        if (entry is Map) {
          rebuilt[entry['email'] as String? ?? ''] =
              Map<String, dynamic>.from(entry);
        }
      }
      return rebuilt;
    }
    // Legacy: the starter wrote the account map at the top level.
    return raw;
  }

  Future<void> _writeUsers(Map<String, dynamic> users) =>
      _storage.writeJson(StorageService.keyUsers, <String, dynamic>{
        'version': 2,
        'accounts': users,
      });

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<bool> isEmailRegistered(String email) async {
    final Map<String, dynamic> users = await _readUsers();
    return users.containsKey(_normalizeEmail(email));
  }

  /// Creates an account. Throws [AuthException] on a duplicate email.
  Future<User> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final String key = _normalizeEmail(email);
    final Map<String, dynamic> users = await _readUsers();
    if (users.containsKey(key)) {
      throw const AuthException('That email is already registered.');
    }

    final String salt = _newSalt();
    final User user = User(
      id: _newId(),
      username: username.trim(),
      email: key,
      passwordHash: _hash(salt, password),
      createdAt: DateTime.now(),
    );

    users[key] = <String, dynamic>{
      ...user.toJson(),
      'salt': salt,
    };
    await _writeUsers(users);
    await _storage.writeString(StorageService.keySession, user.id);
    return user;
  }

  /// Verifies credentials. Throws [AuthException] when they do not match.
  Future<User> login({
    required String email,
    required String password,
  }) async {
    final String key = _normalizeEmail(email);
    final Map<String, dynamic> users = await _readUsers();
    final Object? record = users[key];

    if (record is! Map) {
      throw const AuthException('No account found for that email.');
    }

    final Map<String, dynamic> account = Map<String, dynamic>.from(record);
    final String salt = account['salt'] as String? ?? '';
    final String hash = account['passwordHash'] as String? ?? '';

    // Always run the hash so a missing account and a wrong password take a
    // comparable amount of time.
    final bool ok = verifyPassword(
      salt: salt,
      passwordHash: hash.isEmpty ? _hash(salt, 'placeholder') : hash,
      password: password,
    );
    if (hash.isEmpty || !ok) {
      throw const AuthException('Incorrect email or password.');
    }

    final User user = User.fromJson(account);
    await _storage.writeString(StorageService.keySession, user.id);
    return user;
  }

  /// Restores the signed-in user, or `null` when there is no valid session.
  Future<User?> restoreSession() async {
    final String? userId = await _storage.readString(StorageService.keySession);
    if (userId == null || userId.isEmpty) {
      return null;
    }
    final Map<String, dynamic> users = await _readUsers();
    for (final Object? record in users.values) {
      if (record is Map && record['id'] == userId) {
        return User.fromJson(Map<String, dynamic>.from(record));
      }
    }
    // Session points at a deleted account: clean it up.
    await _storage.remove(StorageService.keySession);
    return null;
  }

  Future<void> logout() => _storage.remove(StorageService.keySession);

  Future<void> updateUsername(String userId, String username) async {
    final Map<String, dynamic> users = await _readUsers();
    for (final String email in users.keys.toList(growable: false)) {
      final Object? record = users[email];
      if (record is Map && record['id'] == userId) {
        users[email] = <String, dynamic>{
          ...Map<String, dynamic>.from(record),
          'username': username.trim(),
        };
        await _writeUsers(users);
        return;
      }
    }
    throw const AuthException('Could not update the profile.');
  }

  /// Removes the account and wipes every per-user bucket.
  Future<void> deleteAccount(String userId) async {
    final Map<String, dynamic> users = await _readUsers();
    users.removeWhere((String email, Object? record) {
      return record is Map && record['id'] == userId;
    });
    await _writeUsers(users);

    final Set<String> keys = await _storage.allKeys();
    final List<String> owned = keys
        .where((String key) => key.startsWith('vv:u:$userId:'))
        .toList(growable: false);
    for (final String key in owned) {
      await _storage.remove(key);
    }
    await _storage.remove(StorageService.keySession);
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _newId() {
    final List<int> bytes =
        List<int>.generate(12, (_) => _random.nextInt(256), growable: false);
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
