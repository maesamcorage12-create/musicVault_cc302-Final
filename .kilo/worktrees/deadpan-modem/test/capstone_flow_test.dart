import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/app/app.dart';
import 'package:vibevault/repositories/auth_repository.dart';
import 'package:vibevault/repositories/playback_repository.dart';
import 'package:vibevault/services/storage_service.dart';

/// The spec §40 flow, driven entirely through the UI:
///
/// register → create a playlist → it shows up in the library → it is still
/// there after the app restarts.
void main() {
  late StorageService storage;

  const AppSettings settings = AppSettings(reduceMotion: true);
  const Size desktop = Size(1280, 900);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = desktop;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      VibeVaultApp(storage: storage, initialSettings: settings),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<void> registerThroughUi(WidgetTester tester) async {
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your vault'), findsOneWidget);

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Test Listener');
    await tester.enterText(fields.at(1), 'test@example.com');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.enterText(fields.at(3), 'secret123');

    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    // Registration succeeded, so the router swapped to the shell.
    expect(find.text('Recently Played'), findsOneWidget);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.clear();
  });

  testWidgets('register → create a playlist → it persists', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await registerThroughUi(tester);

    // Open the Playlists destination from the sidebar.
    await tester.tap(find.text('Playlists').first);
    await tester.pumpAndSettle();
    // First launch seeds the four curated mixes, so the list is never blank.
    for (final String mix in <String>[
      'OPM Love Songs',
      'December Avenue Essentials',
      'Cup of Joe Collection',
      'Ben&Ben Anthology',
    ]) {
      expect(find.text(mix), findsWidgets, reason: 'seeded mix "$mix"');
    }

    // Create one through the dialog.
    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();
    expect(find.text('Create playlist'), findsOneWidget);

    final Finder dialogFields = find.byType(TextFormField);
    await tester.enterText(dialogFields.at(0), 'Late Night Commute');
    await tester.enterText(dialogFields.at(1), 'Quiet drives home');
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    expect(find.text('Late Night Commute'), findsOneWidget);
    expect(find.textContaining('Quiet drives home'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // A duplicate name is refused with a readable message, not a crash.
    await tester.tap(find.widgetWithText(FilledButton, 'New'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'Late Night Commute',
    );
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();
    expect(
      find.text('You already have a playlist with that name.'),
      findsOneWidget,
    );

    // Cold start over the same storage: the playlist must still be there.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpApp(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Recently Played'), findsOneWidget);

    await tester.tap(find.text('Playlists').first);
    await tester.pumpAndSettle();
    expect(find.text('Late Night Commute'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logging out clears the shell and returns to sign-in', (
    WidgetTester tester,
  ) async {
    await AuthRepository(storage).register(
      username: 'Test Listener',
      email: 'test@example.com',
      password: 'secret123',
    );

    await pumpApp(tester);
    expect(find.text('Recently Played'), findsOneWidget);

    await tester.tap(find.text('Profile').first);
    await tester.pumpAndSettle();
    // The header's logout affordance is always visible, unlike the button at
    // the very bottom of the (lazily built) profile list.
    expect(find.byTooltip('Log out'), findsOneWidget);
    await tester.tap(find.byTooltip('Log out'));
    await tester.pumpAndSettle();

    // Confirmation dialog.
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}