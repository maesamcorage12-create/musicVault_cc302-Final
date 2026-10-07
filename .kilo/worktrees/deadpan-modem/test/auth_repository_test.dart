import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/models/user.dart';
import 'package:vibevault/providers/auth_provider.dart';
import 'package:vibevault/repositories/auth_repository.dart';
import 'package:vibevault/services/storage_service.dart';

/// Covers the Authentication section of the spec §37 checklist.
void main() {
  late StorageService storage;
  late AuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.clear();
    repository = AuthRepository(storage);
  });

  Future<User> registerAccount({
    String username = 'Test Listener',
    String email = 'test@example.com',
    String password = 'secret123',
  }) {
    return repository.register(
      username: username,
      email: email,
      password: password,
    );
  }

  group('AuthRepository', () {
    test('registers an account and starts a session', () async {
      final user = await registerAccount();

      expect(user.username, 'Test Listener');
      expect(user.email, 'test@example.com');
      expect(await storage.readString(StorageService.keySession), user.id);
    });

    test('normalises the email so duplicates are detected', () async {
      await registerAccount(email: 'Test@Example.com');

      expect(await repository.isEmailRegistered('test@example.com'), isTrue);
      expect(
        () => registerAccount(email: '  TEST@EXAMPLE.COM  '),
        throwsA(isA<AuthException>()),
      );
    });

    test('never persists the password in plain text', () async {
      await registerAccount(password: 'super-secret-passphrase');

      final raw = await storage.readString(StorageService.keyUsers);
      expect(raw, isNotNull);
      expect(raw, isNot(contains('super-secret-passphrase')));
    });

    test('login succeeds with the right credentials', () async {
      final created = await registerAccount();

      final loggedIn = await repository.login(
        email: 'test@example.com',
        password: 'secret123',
      );

      expect(loggedIn.id, created.id);
      expect(await storage.readString(StorageService.keySession), created.id);
    });

    test('login fails for a wrong password and for an unknown email', () async {
      await registerAccount();

      await expectLater(
        repository.login(email: 'test@example.com', password: 'wrong'),
        throwsA(
          isA<AuthException>().having(
            (AuthException e) => e.message,
            'message',
            'Incorrect email or password.',
          ),
        ),
      );
      await expectLater(
        repository.login(email: 'nobody@example.com', password: 'secret123'),
        throwsA(isA<AuthException>()),
      );
    });

    test('restoreSession returns the user after a simulated restart', () async {
      await registerAccount();

      // A fresh repository over the same storage is what a cold start looks like.
      final restarted = AuthRepository(StorageService());
      final restored = await restarted.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.email, 'test@example.com');
    });

    test('restoreSession returns null when logged out', () async {
      await registerAccount();
      await repository.logout();

      expect(await repository.restoreSession(), isNull);
    });

    test('rename updates the stored account', () async {
      await registerAccount();
      final user = await repository.restoreSession();

      await repository.updateUsername(user!.id, 'Renamed Listener');
      final reloaded = await repository.restoreSession();

      expect(reloaded!.username, 'Renamed Listener');
    });

    test('deleteAccount wipes the account and its per-user keys', () async {
      final user = await registerAccount();
      await storage.writeString(
        StorageService.userKey(user.id, 'playlists'),
        '[]',
      );

      await repository.deleteAccount(user.id);

      expect(await repository.restoreSession(), isNull);
      expect(await repository.isEmailRegistered('test@example.com'), isFalse);
      expect(
        await storage.allKeys(),
        isNot(contains(StorageService.userKey(user.id, 'playlists'))),
      );
    });

    test('password digests depend on the salt, not the password alone', () {
      // Two different accounts with the same password must not share a digest.
      final String saltA = 'aaaaaaaaaaaaaaaa';
      final String saltB = 'bbbbbbbbbbbbbbbb';

      final String digestA = AuthRepository.hashForTesting(saltA, 'letmein123');
      final String digestB = AuthRepository.hashForTesting(saltB, 'letmein123');

      expect(digestA, isNot(digestB));
      expect(
        AuthRepository.verifyPassword(
          salt: saltA,
          passwordHash: digestA,
          password: 'letmein123',
        ),
        isTrue,
      );
      expect(
        AuthRepository.verifyPassword(
          salt: saltA,
          passwordHash: digestA,
          password: 'wrong-password',
        ),
        isFalse,
      );
      expect(
        AuthRepository.verifyPassword(
          salt: saltB,
          passwordHash: digestA,
          password: 'letmein123',
        ),
        isFalse,
      );
    });
  });

  group('AuthProvider validation', () {
    test('email validation accepts valid and rejects invalid addresses', () {
      expect(AuthProvider.isValidEmail('a@b.co'), isTrue);
      expect(AuthProvider.isValidEmail('first.last+tag@sub.domain.io'), isTrue);
      expect(AuthProvider.isValidEmail('nope'), isFalse);
      expect(AuthProvider.isValidEmail('missing@domain'), isFalse);
      expect(AuthProvider.isValidEmail('@example.com'), isFalse);
    });

    test('registration rules fire in the documented order', () {
      String? firstFailure({
        String username = 'Ada',
        String email = 'ada@example.com',
        String password = 'secret123',
        String confirm = 'secret123',
      }) {
        return AuthProvider.validateRegistration(
          username: username,
          email: email,
          password: password,
          confirmPassword: confirm,
        );
      }

      expect(firstFailure(username: ''), 'Username is required.');
      expect(firstFailure(username: 'A'), 'Username must be at least 2 characters.');
      expect(firstFailure(email: 'bad'), 'Enter a valid email address.');
      expect(firstFailure(password: ''), 'Password is required.');
      expect(
        firstFailure(password: '12345'),
        'Password must be at least 6 characters.',
      );
      expect(firstFailure(confirm: 'different'), 'Passwords do not match.');
      expect(firstFailure(), isNull);
    });

    test('register and login drive the provider status', () async {
      final provider = AuthProvider(repository);

      expect(provider.status, AuthStatus.unknown);

      final created = await provider.register(
        username: 'Ada',
        email: 'ada@example.com',
        password: 'secret123',
        confirmPassword: 'secret123',
      );
      expect(created, isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.errorMessage, isNull);

      await provider.logout();
      expect(provider.status, AuthStatus.unauthenticated);

      final ok = await provider.login(
        email: 'ada@example.com',
        password: 'secret123',
      );
      expect(ok, isTrue);
      expect(provider.isAuthenticated, isTrue);
    });

    test('duplicate registration reports an error instead of throwing', () async {
      final provider = AuthProvider(repository);
      await provider.register(
        username: 'Ada',
        email: 'ada@example.com',
        password: 'secret123',
        confirmPassword: 'secret123',
      );

      final second = await provider.register(
        username: 'Ada',
        email: 'ada@example.com',
        password: 'secret123',
        confirmPassword: 'secret123',
      );

      expect(second, isFalse);
      expect(provider.errorMessage, 'That email is already registered.');
    });

    test('restoreSession resolves to unauthenticated with no stored session',
        () async {
      final provider = AuthProvider(repository);
      await provider.restoreSession();

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.busy, isFalse);
    });
  });
}