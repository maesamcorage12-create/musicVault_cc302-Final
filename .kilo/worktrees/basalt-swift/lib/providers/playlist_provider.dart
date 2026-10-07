import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/song_catalog.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../repositories/playlist_repository.dart';
import '../services/storage_service.dart';

/// CRUD + membership state for playlists (spec §21).
///
/// [songsFor] resolves playlist ids against the catalog; membership checks
/// (`containsSong`) power the "add to playlist" sheets.
class PlaylistProvider extends ChangeNotifier {
  PlaylistProvider(this._repository);

  final PlaylistRepository _repository;

  String? _userId;
  bool _loading = false;
  String? _errorMessage;
  bool _seeded = false;

  final List<Playlist> _playlists = <Playlist>[];

  List<Playlist> get playlists => List<Playlist>.unmodifiable(_playlists);
  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _playlists.isEmpty;
  int get playlistCount => _playlists.length;
  bool get hasUser => _userId != null;

  Playlist? byId(String id) {
    for (final Playlist playlist in _playlists) {
      if (playlist.id == id) {
        return playlist;
      }
    }
    return null;
  }

  List<Song> songsFor(Playlist playlist) => SongCatalog.resolve(playlist.songIds);

  bool containsSong(String playlistId, int songId) =>
      byId(playlistId)?.songIds.contains(songId) ?? false;

  /// Playlists that contain [songId] — used by the "add to playlist" sheet.
  List<Playlist> playlistsContaining(int songId) => _playlists
      .where((Playlist p) => p.songIds.contains(songId))
      .toList(growable: false);

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Called from the provider wiring. Never notifies synchronously because it
  /// runs inside a build phase.
  void syncUser(String? userId) {
    if (_userId == userId) {
      return;
    }
    _userId = userId;
    _playlists.clear();
    _seeded = false;
    if (userId == null) {
      _loading = false;
      _scheduleNotify();
      return;
    }
    _loading = true;
    _scheduleNotify();
    unawaited(_load(userId));
  }

  Future<void> _load(String userId) async {
    try {
      List<Playlist> playlists = await _repository.loadAll(userId);
      if (_userId != userId) {
        return;
      }
      // First launch: seed the "Made For You" mixes (spec §17) so Home is
      // never an empty wall of glass.
      if (!_seeded && playlists.isEmpty) {
        playlists = _seedCurated(userId);
        _seeded = true;
        await _repository.saveAll(userId, playlists);
      } else {
        _seeded = true;
      }
      _playlists
        ..clear()
        ..addAll(playlists);
      _errorMessage = null;
    } on StorageException catch (error) {
      _errorMessage = error.message;
    } on Object catch (_) {
      _errorMessage = 'Could not load your playlists.';
    } finally {
      if (_userId == userId) {
        _loading = false;
        _scheduleNotify();
      }
    }
  }

  List<Playlist> _seedCurated(String userId) {
    final DateTime now = DateTime.now();
    return <Playlist>[
      for (int i = 0; i < SongCatalog.curatedPlaylists.length; i++)
        () {
          final PlaylistSeed seed = SongCatalog.curatedPlaylists[i];
          final List<int> ids = seed.genre == null
              ? const <int>[]
              : SongCatalog.all
                  .where((Song s) => s.genre == seed.genre)
                  .map((Song s) => s.id)
                  .toList(growable: false);
          return Playlist(
            id: 'seed-$userId-$i',
            name: seed.title,
            description: seed.description,
            songIds: List<int>.unmodifiable(ids),
            createdAt: now.subtract(Duration(days: i + 1)),
            updatedAt: now,
            artworkSeed: seed.title.hashCode,
          );
        }(),
    ];
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<bool> create({
    required String name,
    String description = '',
    List<int> songIds = const <int>[],
  }) async {
    final String? userId = _userId;
    if (userId == null) {
      _errorMessage = 'Sign in to create playlists.';
      _scheduleNotify();
      return false;
    }
    try {
      final Playlist created = await _repository.create(
        userId: userId,
        name: name,
        description: description,
        songIds: songIds,
      );
      _playlists.insert(0, created);
      _errorMessage = null;
      _scheduleNotify();
      return true;
    } on PlaylistException catch (error) {
      _errorMessage = error.message;
      _scheduleNotify();
      return false;
    } on Object catch (_) {
      _errorMessage = 'Playlist creation failed. Please try again.';
      _scheduleNotify();
      return false;
    }
  }

  Future<bool> rename({
    required String playlistId,
    required String name,
    String? description,
  }) async {
    final String? userId = _userId;
    if (userId == null) {
      return false;
    }
    try {
      await _repository.rename(
        userId: userId,
        playlistId: playlistId,
        name: name,
        description: description,
      );
      await _reload();
      return true;
    } on PlaylistException catch (error) {
      _errorMessage = error.message;
      _scheduleNotify();
      return false;
    } on Object catch (_) {
      _errorMessage = 'Could not rename the playlist.';
      _scheduleNotify();
      return false;
    }
  }

  Future<bool> delete(String playlistId) async {
    final String? userId = _userId;
    if (userId == null) {
      return false;
    }
    try {
      await _repository.delete(userId: userId, playlistId: playlistId);
      _playlists.removeWhere((Playlist p) => p.id == playlistId);
      _errorMessage = null;
      _scheduleNotify();
      return true;
    } on PlaylistException catch (error) {
      _errorMessage = error.message;
      _scheduleNotify();
      return false;
    } on Object catch (_) {
      _errorMessage = 'Could not delete the playlist.';
      _scheduleNotify();
      return false;
    }
  }

  Future<bool> addSong(String playlistId, int songId) async {
    final String? userId = _userId;
    if (userId == null) {
      return false;
    }
    try {
      await _repository.addSong(
        userId: userId,
        playlistId: playlistId,
        songId: songId,
      );
      await _reload();
      return true;
    } on PlaylistException catch (error) {
      _errorMessage = error.message;
      _scheduleNotify();
      return false;
    } on Object catch (_) {
      _errorMessage = 'Could not add that song.';
      _scheduleNotify();
      return false;
    }
  }

  Future<bool> removeSong(String playlistId, int songId) async {
    final String? userId = _userId;
    if (userId == null) {
      return false;
    }
    try {
      await _repository.removeSong(
        userId: userId,
        playlistId: playlistId,
        songId: songId,
      );
      await _reload();
      return true;
    } on PlaylistException catch (error) {
      _errorMessage = error.message;
      _scheduleNotify();
      return false;
    } on Object catch (_) {
      _errorMessage = 'Could not remove that song.';
      _scheduleNotify();
      return false;
    }
  }

  Future<bool> reorder(String playlistId, int oldIndex, int newIndex) async {
    final String? userId = _userId;
    if (userId == null) {
      return false;
    }
    try {
      await _repository.reorder(
        userId: userId,
        playlistId: playlistId,
        oldIndex: oldIndex,
        newIndex: newIndex,
      );
      await _reload();
      return true;
    } on Object catch (_) {
      _errorMessage = 'Could not reorder that playlist.';
      _scheduleNotify();
      return false;
    }
  }

  Future<void> clearAll() async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    await _repository.clearAll(userId);
    _playlists.clear();
    _seeded = false;
    _errorMessage = null;
    _scheduleNotify();
  }

  /// Re-reads from storage after a repository mutation. Using the repository as
  /// the single source of truth keeps the in-memory list byte-identical to disk.
  Future<void> _reload() async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    final List<Playlist> playlists = await _repository.loadAll(userId);
    if (_userId != userId) {
      return;
    }
    _playlists
      ..clear()
      ..addAll(playlists);
    _errorMessage = null;
    _scheduleNotify();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    _scheduleNotify();
  }

  bool _notifyScheduled = false;

  void _scheduleNotify() {
    if (_disposed || _notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
