enum RepeatMode {
  off,
  all,
  one;

  RepeatMode get next {
    switch (this) {
      case RepeatMode.off:
        return RepeatMode.all;
      case RepeatMode.all:
        return RepeatMode.one;
      case RepeatMode.one:
        return RepeatMode.off;
    }
  }

  String get label {
    switch (this) {
      case RepeatMode.off:
        return 'Repeat off';
      case RepeatMode.all:
        return 'Repeat all';
      case RepeatMode.one:
        return 'Repeat one';
    }
  }

  String get shortLabel {
    switch (this) {
      case RepeatMode.off:
        return 'Off';
      case RepeatMode.all:
        return 'All';
      case RepeatMode.one:
        return 'One';
    }
  }

  static RepeatMode fromName(String? name) {
    return RepeatMode.values.firstWhere(
      (RepeatMode mode) => mode.name == name,
      orElse: () => RepeatMode.off,
    );
  }
}

/// Serializable snapshot of the player's user-visible settings (spec §10/§13).
///
/// Stored per account so a second device-less profile can be restored without
/// re-tuning audio.
class PlaybackState {
  const PlaybackState({
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
    this.volume = 1,
    this.lastSongId,
    this.lastPositionMs = 0,
  });

  final bool shuffle;
  final RepeatMode repeatMode;
  final double volume;
  final int? lastSongId;
  final int lastPositionMs;

  PlaybackState copyWith({
    bool? shuffle,
    RepeatMode? repeatMode,
    double? volume,
    int? lastSongId,
    int? lastPositionMs,
  }) {
    return PlaybackState(
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      lastSongId: lastSongId ?? this.lastSongId,
      lastPositionMs: lastPositionMs ?? this.lastPositionMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'shuffle': shuffle,
        'repeatMode': repeatMode.name,
        'volume': volume,
        'lastSongId': lastSongId,
        'lastPositionMs': lastPositionMs,
      };

  factory PlaybackState.fromJson(Map<String, dynamic> json) => PlaybackState(
        shuffle: (json['shuffle'] as bool?) ?? false,
        repeatMode: RepeatMode.fromName(json['repeatMode'] as String?),
        volume: ((json['volume'] as num?) ?? 1).toDouble().clamp(0, 1),
        lastSongId: json['lastSongId'] as int?,
        lastPositionMs: (json['lastPositionMs'] as int?) ?? 0,
      );
}
