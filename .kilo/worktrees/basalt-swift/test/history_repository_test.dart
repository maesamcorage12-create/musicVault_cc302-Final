import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/data/song_catalog.dart';
import 'package:vibevault/models/listening_history.dart';
import 'package:vibevault/models/song.dart';
import 'package:vibevault/repositories/history_repository.dart';
import 'package:vibevault/services/storage_service.dart';

/// Covers the History and Statistics sections of the spec §37 checklist.
void main() {
  late StorageService storage;
  late HistoryRepository repository;

  const String userA = 'user-a';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.clear();
    repository = HistoryRepository(storage);
  });

  group('HistoryRepository', () {
    test('a play appears in history', () async {
      final history = await repository.recordPlay(userA, <HistoryEntry>[], 1);

      expect(history, hasLength(1));
      expect(history.single.songId, 1);
      expect(await repository.loadAll(userA), hasLength(1));
    });

    test('listened seconds are patched onto the latest matching entry',
        () async {
      var history = await repository.recordPlay(userA, <HistoryEntry>[], 4);
      history = await repository.updateLastListen(
        userA,
        history,
        4,
        listenedSeconds: 42,
        completed: true,
      );

      final reloaded = await repository.loadAll(userA);
      expect(reloaded.single.listenedSeconds, 42);
      expect(reloaded.single.completed, isTrue);
    });

    test('updateLastListen patches the newest entry for a repeated song',
        () async {
      var history = await repository.recordPlay(userA, <HistoryEntry>[], 4);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      history = await repository.recordPlay(userA, history, 4);
      history = await repository.updateLastListen(
        userA,
        history,
        4,
        listenedSeconds: 9,
      );

      expect(history, hasLength(2));
      expect(history.last.listenedSeconds, 9);
      expect(history.first.listenedSeconds, 0);
    });

    test('updateLastListen is a no-op for an unknown song', () async {
      final history = <HistoryEntry>[];
      final next = await repository.updateLastListen(
        userA,
        history,
        99,
        listenedSeconds: 5,
      );

      expect(next, same(history));
      expect(await repository.loadAll(userA), isEmpty);
    });

    test('history survives a restart', () async {
      await repository.recordPlay(userA, <HistoryEntry>[], 2);
      await repository.recordPlay(userA, await repository.loadAll(userA), 3);

      final afterRestart = HistoryRepository(StorageService());
      expect(await afterRestart.loadAll(userA), hasLength(2));
    });

    test('history is scoped per user', () async {
      await repository.recordPlay(userA, <HistoryEntry>[], 2);
      expect(await repository.loadAll('user-b'), isEmpty);
    });

    test('clear removes every entry', () async {
      await repository.recordPlay(userA, <HistoryEntry>[], 2);
      await repository.clear(userA);
      expect(await repository.loadAll(userA), isEmpty);
    });

    test('older entries are trimmed past the configured cap', () async {
      final capped = HistoryRepository(storage, maxEntries: 5);
      List<HistoryEntry> history = <HistoryEntry>[];
      for (int i = 0; i < 12; i++) {
        history = await capped.recordPlay(userA, history, 1);
      }

      final loaded = await capped.loadAll(userA);
      expect(loaded, hasLength(5));
    });
  });

  group('recentlyPlayed', () {
    List<HistoryEntry> makeHistory(List<int> songIds) => <HistoryEntry>[
          for (int i = 0; i < songIds.length; i++)
            HistoryEntry(
              songId: songIds[i],
              playedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
              listenedSeconds: 30,
            ),
        ];

    test('returns newest first', () {
      final recent = HistoryRepository.recentlyPlayed(
        makeHistory(<int>[1, 2, 3]),
        SongCatalog.all,
      );

      expect(recent.map((Song s) => s.id), <int>[3, 2, 1]);
    });

    test('de-duplicates so a replayed track only appears once', () {
      final recent = HistoryRepository.recentlyPlayed(
        makeHistory(<int>[1, 2, 1, 3, 2]),
        SongCatalog.all,
      );

      expect(recent.map((Song s) => s.id), <int>[2, 3, 1]);
    });

    test('respects the limit', () {
      final recent = HistoryRepository.recentlyPlayed(
        makeHistory(List<int>.generate(20, (int i) => i + 1)),
        SongCatalog.all,
        limit: 5,
      );

      expect(recent, hasLength(5));
    });

    test('drops song ids that are not in the catalog', () {
      final recent = HistoryRepository.recentlyPlayed(
        makeHistory(<int>[1, 9999, 2]),
        SongCatalog.all,
      );

      expect(recent.map((Song s) => s.id), <int>[2, 1]);
    });
  });

  group('playCounts', () {
    test('counts every play of a song', () {
      final counts = HistoryRepository.playCounts(<HistoryEntry>[
        HistoryEntry(songId: 1, playedAt: DateTime(2026)),
        HistoryEntry(songId: 2, playedAt: DateTime(2026)),
        HistoryEntry(songId: 1, playedAt: DateTime(2026)),
      ]);

      expect(counts[1], 2);
      expect(counts[2], 1);
    });
  });
}