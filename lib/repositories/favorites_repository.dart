import 'dart:async';

import '../models/song.dart';
import '../services/storage_service.dart';

/// Persistence for favourites (spec §20).
///
/// Only song ids are stored, in insertion order, so un-favouriting and
/// re-favouriting behaves predictably and the list survives a restart.
class FavoritesRepository {
  FavoritesRepository(this._storage);

  final StorageService _storage;

  String _key(String userId) => StorageService.userKey(userId, 'favorites');

  Future<List<int>> loadIds(String userId) async {
    final List<dynamic> raw = await _storage.readJsonList(_key(userId));
    final List<int> ids = <int>[];
    final Set<int> seen = <int>{};
    for (final dynamic item in raw) {
      if (item is int && seen.add(item)) {
        ids.add(item);
      }
    }
    return ids;
  }

  Future<void> saveIds(String userId, List<int> ids) =>
      _storage.writeJson(_key(userId), ids);

  /// Adds and removes [songId] in one step. Returns the new list.
  Future<List<int>> toggle(String userId, List<int> current, int songId) async {
    final List<int> next = List<int>.of(current);
    if (next.contains(songId)) {
      next.remove(songId);
    } else {
      next.add(songId);
    }
    await saveIds(userId, next);
    return next;
  }

  Future<List<int>> add(String userId, List<int> current, int songId) async {
    if (current.contains(songId)) {
      return current;
    }
    final List<int> next = <int>[...current, songId];
    await saveIds(userId, next);
    return next;
  }

  Future<List<int>> remove(String userId, List<int> current, int songId) async {
    if (!current.contains(songId)) {
      return current;
    }
    final List<int> next = <int>[...current]..remove(songId);
    await saveIds(userId, next);
    return next;
  }

  Future<void> clear(String userId) => _storage.remove(_key(userId));

  /// Resolves ids to catalog songs, dropping ids that no longer exist.
  static List<Song> resolve(List<int> ids, List<Song> catalog) {
    final Map<int, Song> byId = <int, Song>{
      for (final Song song in catalog) song.id: song,
    };
    return <Song>[
      for (final int id in ids)
        if (byId[id] case final Song song) song,
    ];
  }
}
