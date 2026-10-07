import 'song.dart';

/// Aggregated, always-derived listening statistics (spec §24).
///
/// Nothing here is stored as a running counter in the widget tree: the values
/// are computed from the real history, which is why they can never drift out of
/// sync with what the user actually did.
class ListeningStatistics {
  const ListeningStatistics({
    required this.totalPlays,
    required this.totalListening,
    required this.playCountBySongId,
    required this.listeningSecondsBySongId,
    required this.listeningSecondsByGenre,
    required this.playCountByGenre,
    required this.playlistCount,
    required this.favoriteCount,
  });

  final int totalPlays;
  final Duration totalListening;
  final Map<int, int> playCountBySongId;
  final Map<int, int> listeningSecondsBySongId;
  final Map<String, int> listeningSecondsByGenre;
  final Map<String, int> playCountByGenre;
  final int playlistCount;
  final int favoriteCount;

  static const ListeningStatistics empty = ListeningStatistics(
    totalPlays: 0,
    totalListening: Duration.zero,
    playCountBySongId: <int, int>{},
    listeningSecondsBySongId: <int, int>{},
    listeningSecondsByGenre: <String, int>{},
    playCountByGenre: <String, int>{},
    playlistCount: 0,
    favoriteCount: 0,
  );

  /// Song with the most plays, or `null` when nothing has been played yet.
  Song? mostPlayedSong(List<Song> catalog) {
    if (playCountBySongId.isEmpty) {
      return null;
    }
    int bestId = playCountBySongId.keys.first;
    int bestCount = playCountBySongId[bestId] ?? 0;
    playCountBySongId.forEach((int id, int count) {
      if (count > bestCount) {
        bestCount = count;
        bestId = id;
      }
    });
    return catalog.where((Song song) => song.id == bestId).firstOrNull;
  }

  int playsFor(int songId) => playCountBySongId[songId] ?? 0;

  String? get topGenre {
    if (listeningSecondsByGenre.isEmpty) {
      return null;
    }
    String best = listeningSecondsByGenre.keys.first;
    int bestSeconds = listeningSecondsByGenre[best] ?? 0;
    listeningSecondsByGenre.forEach((String genre, int seconds) {
      if (seconds > bestSeconds) {
        bestSeconds = seconds;
        best = genre;
      }
    });
    return best;
  }

  /// Genre leaderboard sorted by listening time, capped for chart widgets.
  List<MapEntry<String, int>> topGenres({int limit = 5}) {
    final List<MapEntry<String, int>> entries =
        listeningSecondsByGenre.entries.toList()
          ..sort((MapEntry<String, int> a, MapEntry<String, int> b) =>
              b.value.compareTo(a.value));
    return entries.take(limit).toList(growable: false);
  }

  /// Per-song play leaderboard, used by the statistics screen.
  List<MapEntry<Song, int>> topSongs(List<Song> catalog, {int limit = 5}) {
    final List<MapEntry<Song, int>> entries = <MapEntry<Song, int>>[];
    for (final MapEntry<int, int> entry in playCountBySongId.entries) {
      for (final Song song in catalog) {
        if (song.id == entry.key) {
          entries.add(MapEntry<Song, int>(song, entry.value));
        }
      }
    }
    entries.sort(
      (MapEntry<Song, int> a, MapEntry<Song, int> b) =>
          b.value.compareTo(a.value),
    );
    return entries.take(limit).toList(growable: false);
  }

  /// Share of total listening time per genre (0..1), for progress bars.
  double genreShare(String genre) {
    final int total = totalListening.inSeconds;
    if (total <= 0) {
      return 0;
    }
    return (listeningSecondsByGenre[genre] ?? 0) / total;
  }

  /// `6h 42m` / `42m 10s`
  String get formattedListening {
    final int totalMinutes = totalListening.inMinutes;
    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (totalMinutes > 0) {
      return '${totalMinutes}m';
    }
    return '${totalListening.inSeconds}s';
  }
}
