import 'dart:async';

import '../models/listening_history.dart';
import '../models/song.dart';
import '../services/storage_service.dart';

/// Persists the listening history that drives "Recently Played" on Home,
/// "Listening History" in the Profile, and every statistics screen (spec §23/§24).
///
/// One entry is written each time playback *starts*. The listened duration is
/// patched in when playback stops or the track ends, so a play that is skipped
/// immediately still counts as a play but contributes almost no listening time.
class HistoryRepository {
  HistoryRepository(this._storage, {this.maxEntries = 500});

  final StorageService _storage;

  /// Upper bound on stored entries. Older plays are dropped oldest-first so the
  /// stored JSON cannot grow without limit.
  final int maxEntries;

  String _key(String userId) => StorageService.userKey(userId, 'history');

  Future<List<HistoryEntry>> loadAll(String userId) async {
    final List<dynamic> raw = await _storage.readJsonList(_key(userId));
    final List<HistoryEntry> entries = <HistoryEntry>[];
    for (final dynamic item in raw) {
      if (item is! Map) {
        continue;
      }
      try {
        entries.add(
          HistoryEntry.fromJson(Map<String, dynamic>.from(item)),
        );
      } on Object {
        continue;
      }
    }
    return entries;
  }

  Future<void> saveAll(String userId, List<HistoryEntry> entries) {
    final List<HistoryEntry> trimmed = entries.length > maxEntries
        ? entries.sublist(entries.length - maxEntries)
        : entries;
    return _storage.writeJson(
      _key(userId),
      trimmed.map((HistoryEntry e) => e.toJson()).toList(growable: false),
    );
  }

  /// Appends a play. `history` is passed in so the caller can keep the same
  /// list instance it already publishes to the UI.
  Future<List<HistoryEntry>> recordPlay(
    String userId,
    List<HistoryEntry> history,
    int songId, {
    int listenedSeconds = 0,
    bool completed = false,
  }) async {
    final List<HistoryEntry> next = <HistoryEntry>[
      ...history,
      HistoryEntry(
        songId: songId,
        playedAt: DateTime.now(),
        listenedSeconds: listenedSeconds,
        completed: completed,
      ),
    ];
    await saveAll(userId, next);
    return next;
  }

  /// Patches the most recent entry for [songId] with the seconds actually
  /// listened. Returns a new list; no write happens when nothing matched.
  Future<List<HistoryEntry>> updateLastListen(
    String userId,
    List<HistoryEntry> history,
    int songId, {
    required int listenedSeconds,
    bool? completed,
  }) async {
    int index = -1;
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i].songId == songId) {
        index = i;
        break;
      }
    }
    if (index < 0) {
      return history;
    }
    final List<HistoryEntry> next = <HistoryEntry>[...history];
    next[index] = next[index].copyWith(
      listenedSeconds: listenedSeconds,
      completed: completed,
    );
    await saveAll(userId, next);
    return next;
  }

  Future<void> clear(String userId) => _storage.remove(_key(userId));

  // ---------------------------------------------------------------------------
  // Derived views
  // ---------------------------------------------------------------------------

  /// Newest first, de-duplicated: replaying a track moves it to the front
  /// instead of showing it twice (spec §37 "duplicate history handled").
  static List<Song> recentlyPlayed(
    List<HistoryEntry> history,
    List<Song> catalog, {
    int limit = 12,
  }) {
    final Map<int, Song> byId = <int, Song>{
      for (final Song song in catalog) song.id: song,
    };
    final List<Song> result = <Song>[];
    final Set<int> seen = <int>{};
    for (int i = history.length - 1; i >= 0 && result.length < limit; i--) {
      final int id = history[i].songId;
      if (seen.add(id)) {
        final Song? song = byId[id];
        if (song != null) {
          result.add(song);
        }
      }
    }
    return result;
  }

  /// Play counts per song id.
  static Map<int, int> playCounts(List<HistoryEntry> history) {
    final Map<int, int> counts = <int, int>{};
    for (final HistoryEntry entry in history) {
      counts[entry.songId] = (counts[entry.songId] ?? 0) + 1;
    }
    return counts;
  }
}
