import 'dart:async';
import 'dart:convert';

import '../data/song_catalog.dart';
import '../models/playlist.dart';
import '../services/storage_service.dart';

/// CRUD persistence for user playlists (spec §21, §22).
///
/// Lists are stored per user id so two local accounts on the same device never
/// see each other's playlists. Loading drops unknown song ids, which keeps the
/// app working if the catalog is edited later.
class PlaylistRepository {
  PlaylistRepository(this._storage);

  final StorageService _storage;

  String _key(String userId) =>
      StorageService.userKey(userId, 'playlists');

  Future<List<Playlist>> loadAll(String userId) async {
    final List<dynamic> raw = await _storage.readJsonList(_key(userId));
    final List<Playlist> playlists = <Playlist>[];
    for (final dynamic entry in raw) {
      if (entry is! Map) {
        continue;
      }
      try {
        final Playlist playlist = Playlist.fromJson(
          Map<String, dynamic>.from(entry),
        );
        final List<int> validIds = playlist.songIds
            .where((int id) => SongCatalog.byId(id) != null)
            .toList(growable: false);
        playlists.add(playlist.copyWith(songIds: validIds));
      } on Object {
        // Skip malformed entries rather than losing the whole library.
        continue;
      }
    }
    playlists.sort(
      (Playlist a, Playlist b) => b.createdAt.compareTo(a.createdAt),
    );
    return playlists;
  }

  Future<void> saveAll(String userId, List<Playlist> playlists) {
    return _storage.writeJson(
      _key(userId),
      playlists.map((Playlist p) => p.toJson()).toList(growable: false),
    );
  }

  Future<Playlist> create({
    required String userId,
    required String name,
    String description = '',
    List<int> songIds = const <int>[],
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PlaylistException('Playlist name cannot be empty.');
    }
    final List<Playlist> playlists = await loadAll(userId);
    if (playlists.any(
      (Playlist p) => p.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw const PlaylistException('You already have a playlist with that name.');
    }

    final Playlist playlist = Playlist(
      id: _newId(userId, playlists.length),
      name: trimmed,
      description: description.trim(),
      songIds: List<int>.unmodifiable(
        songIds.where((int id) => SongCatalog.byId(id) != null),
      ),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      artworkSeed: trimmed.hashCode,
    );
    playlists.add(playlist);
    await saveAll(userId, playlists);
    return playlist;
  }

  Future<void> rename({
    required String userId,
    required String playlistId,
    required String name,
    String? description,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PlaylistException('Playlist name cannot be empty.');
    }
    final List<Playlist> playlists = await loadAll(userId);
    final int index = playlists.indexWhere((Playlist p) => p.id == playlistId);
    if (index < 0) {
      throw const PlaylistException('That playlist no longer exists.');
    }
    final bool duplicate = playlists.any(
      (Playlist p) =>
          p.id != playlistId &&
          p.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      throw const PlaylistException('You already have a playlist with that name.');
    }
    playlists[index] = playlists[index].copyWith(
      name: trimmed,
      description: description?.trim(),
      updatedAt: DateTime.now(),
    );
    await saveAll(userId, playlists);
  }

  Future<void> delete({
    required String userId,
    required String playlistId,
  }) async {
    final List<Playlist> playlists = await loadAll(userId);
    final int removed = playlists.where((Playlist p) => p.id == playlistId).length;
    if (removed == 0) {
      throw const PlaylistException('That playlist no longer exists.');
    }
    playlists.removeWhere((Playlist p) => p.id == playlistId);
    await saveAll(userId, playlists);
  }

  Future<void> addSong({
    required String userId,
    required String playlistId,
    required int songId,
  }) async {
    final List<Playlist> playlists = await loadAll(userId);
    final int index = playlists.indexWhere((Playlist p) => p.id == playlistId);
    if (index < 0) {
      throw const PlaylistException('That playlist no longer exists.');
    }
    playlists[index] = playlists[index].withSong(songId);
    await saveAll(userId, playlists);
  }

  Future<void> removeSong({
    required String userId,
    required String playlistId,
    required int songId,
  }) async {
    final List<Playlist> playlists = await loadAll(userId);
    final int index = playlists.indexWhere((Playlist p) => p.id == playlistId);
    if (index < 0) {
      throw const PlaylistException('That playlist no longer exists.');
    }
    playlists[index] = playlists[index].withoutSong(songId);
    await saveAll(userId, playlists);
  }

  /// Moves a song inside a playlist, used by the reorderable track list.
  Future<void> reorder({
    required String userId,
    required String playlistId,
    required int oldIndex,
    required int newIndex,
  }) async {
    final List<Playlist> playlists = await loadAll(userId);
    final int index = playlists.indexWhere((Playlist p) => p.id == playlistId);
    if (index < 0 || oldIndex < 0 || oldIndex >= playlists[index].songCount) {
      throw const PlaylistException('Could not reorder that playlist.');
    }
    final List<int> ids = <int>[...playlists[index].songIds];
    final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target < 0 || target >= ids.length) {
      throw const PlaylistException('Could not reorder that playlist.');
    }
    final int moved = ids.removeAt(oldIndex);
    ids.insert(target, moved);
    playlists[index] = playlists[index].copyWith(
      songIds: ids,
      updatedAt: DateTime.now(),
    );
    await saveAll(userId, playlists);
  }

  Future<void> clearAll(String userId) => _storage.remove(_key(userId));

  String _newId(String userId, int existingCount) {
    final String stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '${userId.hashCode.toRadixString(36)}-$existingCount-$stamp';
  }

  /// Encodes a playlist list as JSON. Exposed for tests.
  static String encode(List<Playlist> playlists) =>
      jsonEncode(playlists.map((Playlist p) => p.toJson()).toList());
}

/// Domain-level failure for playlist operations.
class PlaylistException implements Exception {
  const PlaylistException(this.message);

  final String message;

  @override
  String toString() => message;
}
