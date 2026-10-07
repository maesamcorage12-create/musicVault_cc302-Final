// Smoke tests for the app shell: boot, splash → auth gate, and form
// validation. Behavioural coverage of the data layer lives in the sibling
// files (auth_repository_test.dart, playlist_repository_test.dart,
// history_repository_test.dart, catalog_test.dart, widgets_test.dart).
//
// The tests pass `reduceMotion: true` because the LightPillar background runs a
// continuous AnimationController, which would make `pumpAndSettle` never settle.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/app/app.dart';
import 'package:vibevault/repositories/playback_repository.dart';
import 'package:vibevault/services/storage_service.dart';

/// Settings that keep the animated background frozen.
const AppSettings _testSettings = AppSettings(reduceMotion: true);

Future<void> _pumpApp(WidgetTester tester, StorageService storage) async {
  await tester.pumpWidget(
    VibeVaultApp(storage: storage, initialSettings: _testSettings),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.clear();
  });

  testWidgets('app boots into the splash screen', (WidgetTester tester) async {
    await _pumpApp(tester, storage);

    expect(find.text('VibeVault'), findsWidgets);
    expect(find.textContaining('Your music.'), findsOneWidget);
  });

  testWidgets('splash resolves to the sign-in screen', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, storage);
    // Splash is held for 1.7s before the router swaps screens.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('register screen validates before submitting', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, storage);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your vault'), findsOneWidget);

    // Submitting an empty form must surface field errors, not crash.
    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('Username is required.'), findsOneWidget);
  });

  testWidgets('sign-in shows an error for unknown credentials', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester, storage);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'nobody@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.textContaining('No account found'), findsOneWidget);
  });
}