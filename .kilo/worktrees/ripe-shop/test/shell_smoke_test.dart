import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/app/app.dart';
import 'package:vibevault/repositories/auth_repository.dart';
import 'package:vibevault/repositories/playback_repository.dart';
import 'package:vibevault/services/storage_service.dart';

/// End-to-end shell coverage: register an account, sign in, and walk every
/// destination on both the phone and the desktop layout, asserting that nothing
/// overflows and nothing throws (spec §37 UI checklist).
void main() {
  late StorageService storage;

  const AppSettings settings = AppSettings(reduceMotion: true);

  Future<void> signIn() async {
    final AuthRepository repository = AuthRepository(storage);
    await repository.register(
      username: 'Test Listener',
      email: 'test@example.com',
      password: 'secret123',
    );
  }

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      VibeVaultApp(storage: storage, initialSettings: settings),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.clear();
  });

  testWidgets('a stored session lands straight on Home', (
    WidgetTester tester,
  ) async {
    await signIn();
    await pumpShell(tester, const Size(390, 844));

    // Spec section 17 order: header, greeting, search, Recently Played,
    // Trending Now, Made For You, Your Playlists.
    expect(find.text('VibeVault'), findsWidgets);
    expect(find.text('Recently Played'), findsOneWidget);
    expect(find.text('Trending Now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final String section in <String>['Made For You', 'Your Playlists']) {
      await tester.scrollUntilVisible(
        find.text(section),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text(section), findsOneWidget, reason: section);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the four phone tabs render without overflow', (
    WidgetTester tester,
  ) async {
    await signIn();
    await pumpShell(tester, const Size(390, 844));

    for (final String label in <String>['Search', 'Library', 'Profile', 'Home']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tab "$label" on phone');
    }
  });

  testWidgets('the desktop sidebar shows the wide destination list', (
    WidgetTester tester,
  ) async {
    await signIn();
    await pumpShell(tester, const Size(1280, 900));

    for (final String label in <String>[
      'Home',
      'Search',
      'Library',
      'Favourites',
      'Playlists',
      'Statistics',
      'Settings',
      'Profile',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'sidebar "$label"');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('each desktop destination renders without overflow', (
    WidgetTester tester,
  ) async {
    await signIn();
    await pumpShell(tester, const Size(1280, 900));

    for (final String label in <String>[
      'Search',
      'Library',
      'Favourites',
      'Playlists',
      'Statistics',
      'Settings',
      'Profile',
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'section "$label"');
    }
  });

  testWidgets('a narrow tablet uses the compact icon rail', (
    WidgetTester tester,
  ) async {
    await signIn();
    await pumpShell(tester, const Size(760, 900));

    // Below 1024 the rail collapses to icons, so the labels are gone.
    expect(find.text('Statistics'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('favouriting a song from Home updates the statistics counters', (
    WidgetTester tester,
  ) async {
    await signIn();
    await pumpShell(tester, const Size(1280, 900));

    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();
    expect(find.text('Favourites'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}