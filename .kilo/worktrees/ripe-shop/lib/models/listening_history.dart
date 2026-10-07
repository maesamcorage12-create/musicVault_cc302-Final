/// One entry of the listening history.
///
/// A song id can appear many times in history; each entry is a separate play.
/// [listenedSeconds] is what the player actually rendered, not the track length,
/// so partial listens count honestly.
class HistoryEntry {
  const HistoryEntry({
    required this.songId,
    required this.playedAt,
    this.listenedSeconds = 0,
    this.completed = false,
  });

  final int songId;
  final DateTime playedAt;
  final int listenedSeconds;
  final bool completed;

  HistoryEntry copyWith({int? listenedSeconds, bool? completed}) =>
      HistoryEntry(
        songId: songId,
        playedAt: playedAt,
        listenedSeconds: listenedSeconds ?? this.listenedSeconds,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'songId': songId,
        'playedAt': playedAt.toIso8601String(),
        'listenedSeconds': listenedSeconds,
        'completed': completed,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        songId: (json['songId'] as int?) ?? 0,
        playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
            DateTime.now(),
        listenedSeconds: (json['listenedSeconds'] as int?) ?? 0,
        completed: (json['completed'] as bool?) ?? false,
      );
}
