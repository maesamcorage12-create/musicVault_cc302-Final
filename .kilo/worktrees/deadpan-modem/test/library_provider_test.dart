import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/models/listening_history.dart';
import 'package:vibevault/providers/library_provider.dart';
import 'package:vibevault/repositories/favorites_repository.dart';
import 'package:vibevault/repositories/history_repository.dart';
import 'package:vibevault/services/storage_service.dart';

/// Covers the Favorites and History sections of the spec §37 checklist,
/// including persistence across a restart (spec §20).
void main() {
  late StorageService storage;
  late FavoritesRepository favorites;
  late HistoryRepository history;

  const String userA = 'user-a';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.clear();
    favorites = FavoritesRepository(storage);
    history = HistoryRepository(storage);
  });

  Future<LibraryProvider> signedIn() async {
    final provider = LibraryProvider(favorites, history);
    provider.syncUser(userA);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return provider;
  }

  group('favorites', () {
    test('add and remove update the list', () async {
      final provider = await signedIn();

      expect(await provider.toggleFavorite(5), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.isFavorite(5), isTrue);
      expect(provider.favoriteCount, 1);

      expect(await provider.toggleFavorite(5), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.isFavorite(5), isFalse);
      expect(provider.favoriteCount, 0);
    });

    test('favorites resolve to catalog songs in insertion order', () async {
      final provider = await signedIn();

      await provider.toggleFavorite(3);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await provider.toggleFavorite(1);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(provider.favoriteSongs.map((s) => s.id), <int>[3, 1]);
    });

    test('favorites persist after a restart', () async {
      final provider = await signedIn();
      await provider.toggleFavorite(12);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Cold start: new repositories + new provider over the same storage.
      final restarted = LibraryProvider(
        FavoritesRepository(StorageService()),
        HistoryRepository(StorageService()),
      );
      restarted.syncUser(userA);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(restarted.isFavorite(12), isTrue);
      expect(restarted.favoriteCount, 1);
    });

    test('favorites are scoped per user', () async {
      final provider = await signedIn();
      await provider.toggleFavorite(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      provider.syncUser('user-b');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(provider.isFavorite(2), isFalse);

      provider.syncUser(userA);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(provider.isFavorite(2), isTrue);
    });

    test('clearing favorites empties the list', () async {
      final provider = await signedIn();
      await provider.toggleFavorite(2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await provider.clearFavorites();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.favoriteCount, 0);
    });

    test('toggle without a signed-in user reports an error', () async {
      final provider = LibraryProvider(favorites, history);

      expect(await provider.toggleFavorite(1), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.errorMessage, 'Sign in to save favourites.');
    });
  });

  group('history recording', () {
    test('recordPlay appends and appears in recently played', () async {
      final provider = await signedIn();

      await provider.recordPlay(7);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.history, hasLength(1));
      expect(provider.recentlyPlayed().map((s) => s.id), <int>[7]);
    });

    test('replaying a song moves it to the front of recently played',
        () async {
      final provider = await signedIn();
      await provider.recordPlay(1);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await provider.recordPlay(2);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await provider.recordPlay(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        provider.recentlyPlayed().map((s) => s.id),
        <int>[1, 2],
      );
      expect(provider.history, hasLength(3));
    });

    test('finalizePlay patches the listened duration of the last play',
        () async {
      final provider = await signedIn();
      await provider.recordPlay(3);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      await provider.finalizePlay(3, const Duration(seconds: 90));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.history.single.listenedSeconds, 90);
    });

    test('play counts accumulate', () async {
      final provider = await signedIn();
      await provider.recordPlay(4);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await provider.recordPlay(4);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.playCounts[4], 2);
    });

    test('history survives a restart and clearing empties it', () async {
      final provider = await signedIn();
      await provider.recordPlay(6);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final restarted = LibraryProvider(
        FavoritesRepository(StorageService()),
        HistoryRepository(StorageService()),
      );
      restarted.syncUser(userA);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(restarted.history, hasLength(1));

      await restarted.clearHistory();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(restarted.history, isEmpty);
    });

    test('listening history keeps one row per play', () async {
      final provider = await signedIn();
      await provider.recordPlay(8);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await provider.recordPlay(8);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.listeningHistory(), hasLength(2));
    });
  });

  group('HistoryEntry model', () {
    test('round-trips through JSON', () {
      final entry = HistoryEntry(
        songId: 11,
        playedAt: DateTime(2026, 5, 4, 3, 2, 1),
        listenedSeconds: 77,
        completed: true,
      );

      final decoded = HistoryEntry.fromJson(entry.toJson());

      expect(decoded.songId, 11);
      expect(decoded.playedAt, entry.playedAt);
      expect(decoded.listenedSeconds, 77);
      expect(decoded.completed, isTrue);
    });

    test('copyWith only changes the requested fields', () {
      final entry = HistoryEntry(songId: 1, playedAt: DateTime(2026));
      final updated = entry.copyWith(listenedSeconds: 12);

      expect(updated.songId, 1);
      expect(updated.playedAt, entry.playedAt);
      expect(updated.listenedSeconds, 12);
    });
  });
}