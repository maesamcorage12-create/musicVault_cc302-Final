import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/models/playback_state.dart';
import 'package:vibevault/models/song.dart';
import 'package:vibevault/providers/player_provider.dart';
import 'package:vibevault/repositories/playback_repository.dart';
import 'package:vibevault/services/audio_service.dart';
import 'package:vibevault/services/storage_service.dart';
import 'package:vibevault/theme/app_colors.dart';
import 'package:vibevault/theme/app_dimensions.dart';
import 'package:vibevault/theme/app_theme.dart';
import 'package:vibevault/widgets/artwork.dart';
import 'package:vibevault/widgets/empty_state.dart';
import 'package:vibevault/widgets/glass_card.dart';
import 'package:vibevault/widgets/light_pillar_background.dart';
import 'package:vibevault/widgets/mini_player.dart';
import 'package:vibevault/widgets/song_tile.dart';

/// Render-level checks for the design system (spec §5, §7, §15, §29, §32).
void main() {
  Widget host(Widget child, {Size size = const Size(420, 800)}) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    );
  }

  group('theme', () {
    test('uses the specified color system', () {
      expect(VibeColors.deepBackground, const Color(0xFF070A18));
      expect(VibeColors.secondaryBackground, const Color(0xFF10162B));
      expect(VibeColors.electricBlue, const Color(0xFF5227FF));
      expect(VibeColors.brightBlue, const Color(0xFF4DA6FF));
      expect(VibeColors.neonPink, const Color(0xFFFF5DA2));
      expect(VibeColors.softPink, const Color(0xFFFF9FFC));
      expect(VibeColors.white, const Color(0xFFF8F7FF));
      expect(VibeColors.mutedText, const Color(0xFFA9AEC4));
    });

    test('primary gradient runs electric blue to neon pink', () {
      expect(VibeColors.primaryGradient.colors,
          <Color>[VibeColors.electricBlue, VibeColors.neonPink]);
      expect(VibeColors.secondaryGradient.colors,
          <Color>[VibeColors.brightBlue, VibeColors.softPink]);
    });

    test('accentPairFor is deterministic and bounded', () {
      final first = VibeColors.accentPairFor(7);
      expect(VibeColors.accentPairFor(7), first);
      expect(first.$1, isNot(first.$2));
    });

    test('dark theme is the only theme and uses Material 3', () {
      expect(AppTheme.dark.useMaterial3, isTrue);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.dark.scaffoldBackgroundColor, VibeColors.deepBackground);
    });

    test('border radius tokens match the spec', () {
      expect(AppDimensions.radiusCard, inInclusiveRange(20, 24));
      expect(AppDimensions.radiusButton, inInclusiveRange(14, 18));
    });

    test('breakpoints match the spec', () {
      expect(AppBreakpoints.desktop, 700);
      expect(AppBreakpoints.isMobile(699), isTrue);
      expect(AppBreakpoints.isDesktop(700), isTrue);
      expect(AppBreakpoints.isDesktop(1400), isTrue);
    });
  });

  group('LightPillarBackground', () {
    testWidgets('paints without error at every quality', (
      WidgetTester tester,
    ) async {
      for (final BackgroundQuality quality in BackgroundQuality.values) {
        await tester.pumpWidget(
          host(
            LightPillarBackground(
              quality: quality,
              child: const Center(child: Text('content')),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('content'), findsOneWidget, reason: '$quality');
        expect(tester.takeException(), isNull, reason: '$quality');
      }
    });

    testWidgets('does not swallow taps on its child', (
      WidgetTester tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          LightPillarBackground(
            reduceMotion: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const Center(child: Text('tap me')),
            ),
          ),
        ),
      );

      await tester.tap(find.text('tap me'));
      expect(taps, 1, reason: 'spec §4: background must not block input');
    });

    testWidgets('reduce motion freezes the animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          LightPillarBackground(
            reduceMotion: true,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      // A still controller means pumpAndSettle can finish.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the animated background keeps running', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          LightPillarBackground(
            quality: BackgroundQuality.low,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(
        tester.binding.transientCallbackCount,
        greaterThan(0),
        reason: 'the pillar field should be animating',
      );
    });
  });

  group('GlassCard', () {
    testWidgets('renders its child and honours taps', (WidgetTester tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          GlassCard(
            onTap: () => taps++,
            child: const Text('glass'),
          ),
        ),
      );

      expect(find.text('glass'), findsOneWidget);
      await tester.tap(find.text('glass'));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('all three intensities render', (WidgetTester tester) async {
      for (final GlassIntensity intensity in GlassIntensity.values) {
        await tester.pumpWidget(
          host(GlassCard(intensity: intensity, child: const Text('x'))),
        );
        expect(tester.takeException(), isNull, reason: '$intensity');
      }
    });
  });

  group('SongTile', () {
    final Song song = SongCatalogSample.song;

    testWidgets('shows title, artist and album', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 380,
            height: 80,
            child: SongTile(song: song),
          ),
        ),
      );

      expect(find.text(song.title), findsOneWidget);
      expect(find.textContaining(song.artist), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('favorite icon toggles', (WidgetTester tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 380,
            height: 80,
            child: SongTile(
              song: song,
              isFavorite: false,
              onToggleFavorite: () => toggled++,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      expect(toggled, 1);
    });

    testWidgets('shows the playing indicator for the active track', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 380,
            height: 80,
            child: SongTile(song: song, isPlaying: true),
          ),
        ),
      );

      expect(find.byType(PlayingIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long title does not overflow', (WidgetTester tester) async {
      final Song long = Song(
        id: 99,
        title: 'A very very very very very very very very long track title',
        artist: 'An equally long artist name that keeps going',
        album: 'And a long album name as well',
        genre: 'Chill',
        audioPath: 'audio/song_01.mp3',
        duration: const Duration(minutes: 3),
      );

      await tester.pumpWidget(
        host(
          SizedBox(
            width: 260,
            height: 80,
            child: SongTile(song: long, trailingLabel: '1:00:00'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('Artwork', () {
    testWidgets('renders generated covers deterministically', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(Row(children: <Widget>[
          Artwork(seed: 1, size: 80),
          Artwork(seed: 1, size: 80),
          Artwork(seed: 2, size: 80),
        ])),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('avatar renders initials', (WidgetTester tester) async {
      await tester.pumpWidget(host(const Avatar(initials: 'VV', seed: 3)));
      expect(find.text('VV'), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('shows the icon, copy and action', (WidgetTester tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        host(
          EmptyState(
            icon: Icons.queue_music_rounded,
            title: 'Your library is empty.',
            message: 'Create your first playlist.',
            actionLabel: '+ CREATE PLAYLIST',
            onAction: () => tapped++,
          ),
        ),
      );

      expect(find.text('Your library is empty.'), findsOneWidget);
      expect(find.text('Create your first playlist.'), findsOneWidget);
      await tester.tap(find.text('+ CREATE PLAYLIST'));
      expect(tapped, 1);
    });

    testWidgets('omits the action when no handler is given', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          const EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No liked songs yet.',
            message: 'Tap the heart on a song to save it here.',
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('ErrorView', () {
    testWidgets('renders the message and retries', (WidgetTester tester) async {
      var retries = 0;
      await tester.pumpWidget(
        host(
          ErrorView(message: 'Could not load your library.', onRetry: () => retries++),
        ),
      );

      expect(find.text('Could not load your library.'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });
  });

  group('MiniPlayer', () {
    testWidgets('stays hidden until there is a queue', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final player = PlayerProvider(AudioService(), PlaybackRepository(StorageService()));

      await tester.pumpWidget(
        host(
          SizedBox(
            height: 100,
            child: MiniPlayer(
              player: player,
              isFavorite: (_) => false,
              onToggleFavorite: (_) {},
              onOpen: () {},
            ),
          ),
        ),
      );

      expect(find.text('Nothing playing'), findsNothing);
      expect(tester.takeException(), isNull);

      player.dispose();
    });
  });

  group('repeat mode indicator', () {
    test('all three modes have distinct labels', () {
      final Set<String> labels = <String>{
        RepeatMode.off.label,
        RepeatMode.all.label,
        RepeatMode.one.label,
      };
      expect(labels, hasLength(3));
    });
  });
}

/// Small local helper so the test does not depend on the whole catalog.
abstract final class SongCatalogSample {
  static final Song song = const Song(
    id: 1,
    title: 'Midnight Drive',
    artist: 'Neon Harbor',
    album: 'Night Sessions',
    genre: 'Chill',
    audioPath: 'audio/song_01.mp3',
    duration: Duration(seconds: 25),
  );
}