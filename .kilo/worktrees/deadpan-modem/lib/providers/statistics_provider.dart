import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/song_catalog.dart';
import '../models/listening_history.dart';
import '../models/song.dart';
import '../models/statistics.dart';
import '../repositories/history_repository.dart';
import 'library_provider.dart';
import 'playlist_provider.dart';

/// Derives the "YOUR VIBES" numbers on the Profile/Statistics screens from real
/// user activity (spec §24).
///
/// Nothing is incremented by the UI: every value is recomputed from
/// [LibraryProvider]'s history and favourites plus [PlaylistProvider]'s count.
/// That is why the statistics can never disagree with what actually happened.
class StatisticsProvider extends ChangeNotifier {
  ListeningStatistics _statistics = ListeningStatistics.empty;

  ListeningStatistics get statistics => _statistics;

  bool get hasActivity => _statistics.totalPlays > 0;

  int get totalPlays => _statistics.totalPlays;
  Duration get totalListening => _statistics.totalListening;
  int get playlistCount => _statistics.playlistCount;
  int get favoriteCount => _statistics.favoriteCount;
  String? get topGenre => _statistics.topGenre;

  Song? get mostPlayedSong => _statistics.mostPlayedSong(SongCatalog.all);
  List<MapEntry<Song, int>> topSongs({int limit = 5}) =>
      _statistics.topSongs(SongCatalog.all, limit: limit);
  List<MapEntry<String, int>> topGenres({int limit = 5}) =>
      _statistics.topGenres(limit: limit);
  double genreShare(String genre) => _statistics.genreShare(genre);
  int playsFor(int songId) => _statistics.playsFor(songId);

  LibraryProvider? _library;
  PlaylistProvider? _playlists;
  bool _bound = false;
  bool _scheduled = false;
  bool _disposed = false;

  /// Wires the dependencies. Called from the provider tree on every build, so
  /// the initial recompute happens *without* notifying (listeners are not
  /// registered for this provider yet at that point).
  void bind(LibraryProvider? library, PlaylistProvider? playlists) {
    _library = library;
    _playlists = playlists;

    if (!_bound && library != null) {
      _bound = true;
      library.addListener(_invalidate);
    }
    if (_playlists != null && !_playlistsBound) {
      _playlistsBound = true;
      playlists!.addListener(_invalidate);
    }
    _recompute(notify: false);
  }

  bool _playlistsBound = false;

  /// Recomputation is deferred by one microtask so a notification never lands
  /// while Flutter is mid-build (which would throw "setState during build").
  void _invalidate() {
    if (_disposed || _scheduled) {
      return;
    }
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (_disposed) {
        return;
      }
      _recompute(notify: true);
    });
  }

  void _recompute({required bool notify}) {
    _statistics = derive(
      history: _library?.history ?? const <HistoryEntry>[],
      favorites: _library?.favoriteCount ?? 0,
      playlists: _playlists?.playlistCount ?? 0,
    );
    if (notify) {
      notifyListeners();
    }
  }

  /// Pure function: history plus the two counts in, statistics out. Public so it
  /// can be unit-tested without a provider tree.
  static ListeningStatistics derive({
    required List<HistoryEntry> history,
    required int favorites,
    required int playlists,
  }) {
    final Map<int, int> playCounts = HistoryRepository.playCounts(history);
    final Map<int, int> listeningBySong = <int, int>{};
    final Map<String, int> listeningByGenre = <String, int>{};
    final Map<String, int> playsByGenre = <String, int>{};

    int totalListeningSeconds = 0;
    for (final HistoryEntry entry in history) {
      final Song? song = SongCatalog.byId(entry.songId);
      if (song == null) {
        continue;
      }
      final int listened = entry.listenedSeconds;
      totalListeningSeconds += listened;
      listeningBySong[entry.songId] = (listeningBySong[entry.songId] ?? 0) + listened;
      listeningByGenre[song.genre] = (listeningByGenre[song.genre] ?? 0) + listened;
      playsByGenre[song.genre] = (playsByGenre[song.genre] ?? 0) + 1;
    }

    return ListeningStatistics(
      totalPlays: playCounts.isEmpty ? 0 : _sum(playCounts.values),
      totalListening: Duration(seconds: totalListeningSeconds),
      playCountBySongId: playCounts,
      listeningSecondsBySongId: listeningBySong,
      listeningSecondsByGenre: listeningByGenre,
      playCountByGenre: playsByGenre,
      playlistCount: playlists,
      favoriteCount: favorites,
    );
  }

  static int _sum(Iterable<int> values) {
    int total = 0;
    for (final int value in values) {
      total += value;
    }
    return total;
  }

  @override
  void dispose() {
    _disposed = true;
    _library?.removeListener(_invalidate);
    _playlists?.removeListener(_invalidate);
    super.dispose();
  }
}
