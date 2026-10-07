import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vibevault/models/playlist.dart';
import 'package:vibevault/providers/playlist_provider.dart';
import 'package:vibevault/repositories/playlist_repository.dart';
import 'package:vibevault/services/storage_service.dart';

/// Covers the Playlists section of the spec §37 checklist, including
/// persistence across a simulated restart (spec §22).
void main() {
  late StorageService storage;
  late PlaylistRepository repository;

  const String userA = 'user-a';
  const String userB = 'user-b';

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    storage = StorageService();
    await storage.clear();
    repository = PlaylistRepository(storage);
  });

  group('PlaylistRepository CRUD', () {
    test('create persists a playlist with its metadata', () async {
      final created = await repository.create(
        userId: userA,
        name: 'Night Vibes',
        description: 'Late-night music',
      );

      expect(created.name, 'Night Vibes');
      expect(created.songIds, isEmpty);
      expect(created.isEmpty, isTrue);

      final loaded = await repository.loadAll(userA);
      expect(loaded, hasLength(1));
      expect(loaded.single.description, 'Late-night music');
    });

    test('create rejects an empty name and a duplicate name', () async {
      await repository.create(userId: userA, name: 'Focus');

      await expectLater(
        repository.create(userId: userA, name: '   '),
        throwsA(isA<PlaylistException>()),
      );
      await expectLater(
        repository.create(userId: userA, name: 'focus'),
        throwsA(isA<PlaylistException>()),
      );
    });

    test('rename updates name and description', () async {
      final created = await repository.create(userId: userA, name: 'Draft');

      await repository.rename(
        userId: userA,
        playlistId: created.id,
        name: 'Final',
        description: 'Shipped',
      );

      final loaded = await repository.loadAll(userA);
      expect(loaded.single.name, 'Final');
      expect(loaded.single.description, 'Shipped');
      expect(loaded.single.updatedAt, isNotNull);
    });

    test('rename on a missing playlist throws', () async {
      await expectLater(
        repository.rename(
          userId: userA,
          playlistId: 'does-not-exist',
          name: 'Nope',
        ),
        throwsA(isA<PlaylistException>()),
      );
    });

    test('add and remove songs', () async {
      final created = await repository.create(userId: userA, name: 'Mix');

      await repository.addSong(
        userId: userA,
        playlistId: created.id,
        songId: 3,
      );
      await repository.addSong(
        userId: userA,
        playlistId: created.id,
        songId: 7,
      );
      expect((await repository.loadAll(userA)).single.songIds, <int>[3, 7]);

      // Adding the same song twice is a no-op.
      await repository.addSong(
        userId: userA,
        playlistId: created.id,
        songId: 3,
      );
      expect((await repository.loadAll(userA)).single.songIds, <int>[3, 7]);

      await repository.removeSong(
        userId: userA,
        playlistId: created.id,
        songId: 3,
      );
      expect((await repository.loadAll(userA)).single.songIds, <int>[7]);
    });

    test('unknown song ids are dropped when creating', () async {
      final created = await repository.create(
        userId: userA,
        name: 'Curated',
        songIds: <int>[1, 9999, 2],
      );
      expect(created.songIds, <int>[1, 2]);

      final loaded = await repository.loadAll(userA);
      expect(loaded.single.songIds, <int>[1, 2]);
    });

    test('reorder moves a song', () async {
      final created = await repository.create(
        userId: userA,
        name: 'Order',
        songIds: <int>[1, 2, 3, 4],
      );

      // Flutter's ReorderableList semantics: newIndex is the position the item
      // takes *before* the removal is accounted for.
      await repository.reorder(
        userId: userA,
        playlistId: created.id,
        oldIndex: 0,
        newIndex: 2,
      );

      expect((await repository.loadAll(userA)).single.songIds, <int>[2, 1, 3, 4]);
    });

    test('delete removes the playlist and throws when absent', () async {
      final created = await repository.create(userId: userA, name: 'Temp');

      await repository.delete(userId: userA, playlistId: created.id);
      expect(await repository.loadAll(userA), isEmpty);

      await expectLater(
        repository.delete(userId: userA, playlistId: created.id),
        throwsA(isA<PlaylistException>()),
      );
    });

    test('playlists are scoped per user', () async {
      await repository.create(userId: userA, name: 'Mine');
      await repository.create(userId: userB, name: 'Theirs');

      expect((await repository.loadAll(userA)).single.name, 'Mine');
      expect((await repository.loadAll(userB)).single.name, 'Theirs');
    });

    test('playlists survive a restart', () async {
      final created = await repository.create(
        userId: userA,
        name: 'Persisted',
        songIds: <int>[5, 9],
      );

      // A brand-new repository instance over the same storage = cold start.
      final afterRestart = PlaylistRepository(StorageService());
      final loaded = await afterRestart.loadAll(userA);

      expect(loaded, hasLength(1));
      expect(loaded.single.id, created.id);
      expect(loaded.single.songIds, <int>[5, 9]);
    });

    test('malformed entries are skipped instead of losing the library',
        () async {
      // A deliberately corrupt store: a non-object record, a record whose
      // songIds are the wrong type, and one valid playlist.
      await storage.writeJson(StorageService.userKey(userA, 'playlists'), [
        'not an object at all',
        <String, dynamic>{
          'id': 'broken',
          'name': 'Broken',
          'songIds': <String>['one', 'two'],
          'createdAt': DateTime.now().toIso8601String(),
        },
        Playlist.fromJson(<String, dynamic>{
          'id': 'ok',
          'name': 'Good',
          'songIds': <int>[1],
          'createdAt': DateTime.now().toIso8601String(),
        }).toJson(),
      ]);

      final loaded = await repository.loadAll(userA);
      expect(loaded, hasLength(2));
      expect(
        loaded.map((Playlist p) => p.name),
        containsAll(<String>['Broken', 'Good']),
      );
      // The wrong-typed song ids are filtered away instead of crashing.
      expect(
        loaded.firstWhere((Playlist p) => p.name == 'Broken').songIds,
        isEmpty,
      );
      expect(
        loaded.firstWhere((Playlist p) => p.name == 'Good').songIds,
        <int>[1],
      );
    });
  });

  group('PlaylistProvider', () {
    test('seeds the curated mixes on first launch only', () async {
      final provider = PlaylistProvider(repository);
      provider.syncUser(userA);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.playlistCount, greaterThanOrEqualTo(4));
      expect(provider.isLoading, isFalse);

      provider.syncUser(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(provider.playlistCount, 0);
    });

    test('create / rename / add / remove go through the repository', () async {
      final provider = PlaylistProvider(repository);
      provider.syncUser(userA);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final created = await provider.create(name: 'Run', description: '5k');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(created, isTrue);

      final playlist = provider.playlists.firstWhere(
        (Playlist p) => p.name == 'Run',
      );

      expect(await provider.rename(playlistId: playlist.id, name: 'Jog'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.byId(playlist.id)!.name, 'Jog');

      expect(await provider.addSong(playlist.id, 4), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.containsSong(playlist.id, 4), isTrue);
      expect(provider.playlistsContaining(4), isNotEmpty);

      expect(await provider.removeSong(playlist.id, 4), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.containsSong(playlist.id, 4), isFalse);

      expect(await provider.delete(playlist.id), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.byId(playlist.id), isNull);
    });

    test('reports failures through errorMessage instead of throwing', () async {
      final provider = PlaylistProvider(repository);
      provider.syncUser(userA);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await provider.create(name: '   '), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.errorMessage, isNotNull);

      provider.clearError();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.errorMessage, isNull);
    });

    test('refuses to mutate without a signed-in user', () async {
      final provider = PlaylistProvider(repository);

      expect(await provider.create(name: 'Nope'), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.errorMessage, 'Sign in to create playlists.');
    });
  });
}