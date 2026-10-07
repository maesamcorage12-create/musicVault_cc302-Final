import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/song_catalog.dart';
import '../models/listening_history.dart';
import '../models/song.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/history_repository.dart';
import '../services/storage_service.dart';

/// Owns the listener's personal library: favourites and listening history
/// (spec §20 and §23).
///
/// Both datasets are per-user and both are loaded/persisted through
/// repositories — the widgets only ever see resolved [Song] objects.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._favorites, this._history);

  final FavoritesRepository _favorites;
  final HistoryRepository _history;

  String? _userId;
  bool _loading = false;
  String? _errorMessage;

  final List<int> _favoriteIds = <int>[];
  final List<HistoryEntry> _historyEntries = <HistoryEntry>[];

  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;
  bool get hasUser => _userId != null;
  List<int> get favoriteIds => List<int>.unmodifiable(_favoriteIds);
  List<HistoryEntry> get history => List<HistoryEntry>.unmodifiable(_historyEntries);

  List<Song> get favoriteSongs =>
      FavoritesRepository.resolve(_favoriteIds, SongCatalog.all);

  bool isFavorite(int songId) => _favoriteIds.contains(songId);

  int get favoriteCount => _favoriteIds.length;

  /// Newest-first, de-duplicated, resolved to songs.
  List<Song> recentlyPlayed({int limit = 12}) =>
      HistoryRepository.recentlyPlayed(_historyEntries, SongCatalog.all, limit: limit);

  /// Full chronological listening history (newest first) for the Profile page.
  List<Song> listeningHistory({int limit = 200}) {
    final List<HistoryEntry> newestFirst =
        _historyEntries.reversed.take(limit).toList(growable: false);
    final List<Song> songs = SongCatalog.resolve(
      newestFirst.map((HistoryEntry e) => e.songId),
    );
    // Preserve one row per play, including repeats.
    final List<Song> ordered = <Song>[];
    for (final HistoryEntry entry in newestFirst) {
      for (final Song song in songs) {
        if (song.id == entry.songId) {
          ordered.add(song);
          break;
        }
      }
    }
    return ordered;
  }

  Map<int, int> get playCounts => HistoryRepository.playCounts(_historyEntries);

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Called by the provider wiring whenever the signed-in account changes.
  ///
  /// Runs inside a build phase (ProxyProvider.update), so it never notifies
  /// synchronously — it schedules the async load instead.
  void syncUser(String? userId) {
    if (_userId == userId) {
      return;
    }
    _userId = userId;
    _favoriteIds.clear();
    _historyEntries.clear();
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
      final List<int> ids = await _favorites.loadIds(userId);
      final List<HistoryEntry> entries = await _history.loadAll(userId);
      if (_userId != userId) {
        return; // Signed out while loading.
      }
      _favoriteIds
        ..clear()
        ..addAll(ids);
      _historyEntries
        ..clear()
        ..addAll(entries);
      _errorMessage = null;
    } on StorageException catch (error) {
      _errorMessage = error.message;
    } on Object catch (_) {
      _errorMessage = 'Could not load your library.';
    } finally {
      if (_userId == userId) {
        _loading = false;
        _scheduleNotify();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Favourites
  // ---------------------------------------------------------------------------

  Future<bool> toggleFavorite(int songId) async {
    final String? userId = _userId;
    if (userId == null) {
      _errorMessage = 'Sign in to save favourites.';
      _scheduleNotify();
      return false;
    }

    final List<int> previous = List<int>.of(_favoriteIds);
    final bool wasFavorite = previous.contains(songId);
    final List<int> optimistic = List<int>.of(previous);
    if (wasFavorite) {
      optimistic.remove(songId);
    } else {
      optimistic.add(songId);
    }

    // Optimistic update so the heart animates immediately (spec §32). The list
    // we persist is the same list we show, never a second toggle of the same id.
    _favoriteIds
      ..clear()
      ..addAll(optimistic);
    _scheduleNotify();

    try {
      await _favorites.saveIds(userId, optimistic);
      _errorMessage = null;
    } on Object catch (_) {
      _favoriteIds
        ..clear()
        ..addAll(previous);
      _errorMessage = 'Could not update your favourites.';
    }
    _scheduleNotify();
    return !wasFavorite;
  }

  // ---------------------------------------------------------------------------
  // History (driven by the player)
  // ---------------------------------------------------------------------------

  /// Called by [PlayerProvider] every time a track starts.
  Future<void> recordPlay(int songId) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    try {
      final List<HistoryEntry> next = await _history.recordPlay(
        userId,
        _historyEntries,
        songId,
      );
      if (_userId != userId) {
        return;
      }
      _historyEntries
        ..clear()
        ..addAll(next);
      _errorMessage = null;
    } on Object catch (_) {
      _errorMessage = 'Could not save your listening history.';
    }
    _scheduleNotify();
  }

  /// Called by [PlayerProvider] when a track stops, ends or is skipped.
  Future<void> finalizePlay(
    int songId,
    Duration listened, {
    bool completed = false,
  }) async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    try {
      final List<HistoryEntry> next = await _history.updateLastListen(
        userId,
        _historyEntries,
        songId,
        listenedSeconds: listened.inSeconds,
        completed: completed,
      );
      if (_userId != userId) {
        return;
      }
      _historyEntries
        ..clear()
        ..addAll(next);
    } on Object catch (_) {
      // History updates are best effort; never interrupt playback.
    }
    _scheduleNotify();
  }

  Future<void> clearHistory() async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    await _history.clear(userId);
    _historyEntries.clear();
    _errorMessage = null;
    _scheduleNotify();
  }

  Future<void> clearFavorites() async {
    final String? userId = _userId;
    if (userId == null) {
      return;
    }
    await _favorites.clear(userId);
    _favoriteIds.clear();
    _errorMessage = null;
    _scheduleNotify();
  }

  /// Restores the favourite that was optimistically removed by a failed write.
  Future<void> restoreFavorites(String userId) async {
    try {
      final List<int> ids = await _favorites.loadIds(userId);
      if (_userId != userId) {
        return;
      }
      _favoriteIds
        ..clear()
        ..addAll(ids);
    } on Object catch (_) {
      // ignore
    }
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

  /// Defers `notifyListeners` out of the current build/notification frame.
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
