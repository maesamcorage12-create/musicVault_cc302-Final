import 'package:flutter_test/flutter_test.dart';

import 'package:vibevault/data/song_catalog.dart';
import 'package:vibevault/models/listening_history.dart';
import 'package:vibevault/models/statistics.dart';
import 'package:vibevault/providers/statistics_provider.dart';

/// Covers the Statistics section of the spec §37 checklist: the numbers must
/// come from real activity, never from hard-coded values (spec §24).
void main() {
  HistoryEntry play(int songId, {int seconds = 30}) => HistoryEntry(
        songId: songId,
        playedAt: DateTime(2026, 1, 1).add(Duration(seconds: songId)),
        listenedSeconds: seconds,
      );

  group('ListeningStatistics', () {
    test('empty statistics report zeroes', () {
      expect(ListeningStatistics.empty.totalPlays, 0);
      expect(ListeningStatistics.empty.totalListening, Duration.zero);
      expect(ListeningStatistics.empty.mostPlayedSong(SongCatalog.all), isNull);
      expect(ListeningStatistics.empty.topGenre, isNull);
    });

    test('formattedListening reads as hours, minutes or seconds', () {
      ListeningStatistics withDuration(Duration d) => ListeningStatistics(
            totalPlays: 1,
            totalListening: d,
            playCountBySongId: const <int, int>{1: 1},
            listeningSecondsBySongId: const <int, int>{},
            listeningSecondsByGenre: const <String, int>{},
            playCountByGenre: const <String, int>{},
            playlistCount: 0,
            favoriteCount: 0,
          );

      expect(withDuration(const Duration(seconds: 42)).formattedListening, '42s');
      expect(
        withDuration(const Duration(minutes: 42, seconds: 10)).formattedListening,
        '42m',
      );
      expect(
        withDuration(const Duration(hours: 6, minutes: 42)).formattedListening,
        '6h 42m',
      );
    });

    test('mostPlayedSong picks the highest play count', () {
      final ListeningStatistics stats = ListeningStatistics(
        totalPlays: 5,
        totalListening: const Duration(minutes: 5),
        playCountBySongId: const <int, int>{1: 3, 2: 2},
        listeningSecondsBySongId: const <int, int>{},
        listeningSecondsByGenre: const <String, int>{},
        playCountByGenre: const <String, int>{},
        playlistCount: 0,
        favoriteCount: 0,
      );

      expect(stats.mostPlayedSong(SongCatalog.all)!.id, 1);
      expect(stats.playsFor(1), 3);
      expect(stats.playsFor(99), 0);
    });

    test('topGenres sorts by listening time and genreShare is a fraction', () {
      final ListeningStatistics stats = ListeningStatistics(
        totalPlays: 4,
        totalListening: const Duration(seconds: 100),
        playCountBySongId: const <int, int>{1: 2, 3: 2},
        listeningSecondsBySongId: const <int, int>{},
        listeningSecondsByGenre: const <String, int>{'Lo-fi': 70, 'Pop': 30},
        playCountByGenre: const <String, int>{'Lo-fi': 2, 'Pop': 2},
        playlistCount: 0,
        favoriteCount: 0,
      );

      expect(stats.topGenre, 'Lo-fi');
      expect(
        stats.topGenres().map((MapEntry<String, int> e) => e.key),
        <String>['Lo-fi', 'Pop'],
      );
      expect(stats.genreShare('Lo-fi'), closeTo(0.7, 0.001));
      expect(stats.genreShare('Pop'), closeTo(0.3, 0.001));
      expect(stats.genreShare('Chill'), 0);
    });
  });

  group('StatisticsProvider derivation', () {
    test('no activity means zeroed stats', () {
      final provider = StatisticsProvider()..bind(null, null);

      expect(provider.hasActivity, isFalse);
      expect(provider.totalPlays, 0);
      expect(provider.playlistCount, 0);
      expect(provider.favoriteCount, 0);
    });

    test('derives totals from the history it is given', () {
      final provider = StatisticsProvider();
      final List<HistoryEntry> history = <HistoryEntry>[
        play(1, seconds: 20),
        play(1, seconds: 25),
        play(4, seconds: 55),
      ];
      final ListeningStatistics computed = StatisticsProvider.derive(
        history: history,
        favorites: 6,
        playlists: 3,
      );

      // Sanity-check the pure function directly.
      expect(computed.totalPlays, 3);
      expect(computed.totalListening, const Duration(seconds: 100));
      expect(computed.mostPlayedSong(SongCatalog.all)!.id, 1);
      expect(computed.favoriteCount, 6);
      expect(computed.playlistCount, 3);
      // Song 1 is Chill (45s of the 100s total), song 4 is Electronic (55s).
      expect(computed.topGenre, SongCatalog.byId(4)!.genre);
      expect(SongCatalog.byId(4)!.genre, isNot(SongCatalog.byId(1)!.genre));

      provider.bind(null, null);
    });

    test('bind recomputes without notifying during build', () {
      final provider = StatisticsProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.bind(null, null);

      expect(notifications, 0, reason: 'bind must not notify synchronously');
    });
  });
}