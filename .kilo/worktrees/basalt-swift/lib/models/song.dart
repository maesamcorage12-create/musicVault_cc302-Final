import 'dart:math' as math;

/// A single track in the curated VibeVault catalog (max 30 songs, spec §11).
///
/// [duration] is a hint used for display before the audio engine reports the
/// real duration from the decoder. It is a `Duration` so the UI never has to
/// re-parse a string.
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.audioPath,
    required this.duration,
    this.year,
    this.description,
    this.artworkPath,
  });

  /// Stable 1-based catalog id. Persisted inside playlists/history/favourites.
  final int id;
  final String title;
  final String artist;
  final String album;
  final String genre;

  /// Path relative to `assets/`, e.g. `audio/song_01.mp3`.
  final String audioPath;
  final Duration duration;
  final int? year;
  final String? description;

  /// Optional real cover art. The app works without it (spec §33) and falls
  /// back to a deterministic gradient generated from [id].
  final String? artworkPath;

  bool get hasArtwork => artworkPath != null && artworkPath!.isNotEmpty;

  /// Asset key handed to the audio engine.
  String get assetPath => 'assets/$audioPath';

  String get artworkAssetPath => hasArtwork ? 'assets/$artworkPath' : '';

  /// `3:42` / `1:02:07`
  String get formattedDuration => formatDuration(duration);

  static String formatDuration(Duration value) {
    final int totalSeconds = math.max(0, value.inSeconds);
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$mm:$ss';
    }
    return '$minutes:$ss';
  }

  /// Lower-cased haystack used by search so filtering stays allocation-light.
  String get searchIndex =>
      '$title $artist $album $genre ${year ?? ''}'.toLowerCase();

  Song copyWith({
    String? title,
    String? artist,
    String? album,
    String? genre,
    Duration? duration,
    int? year,
    String? description,
    String? artworkPath,
  }) {
    return Song(
      id: id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      genre: genre ?? this.genre,
      audioPath: audioPath,
      duration: duration ?? this.duration,
      year: year ?? this.year,
      description: description ?? this.description,
      artworkPath: artworkPath ?? this.artworkPath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'genre': genre,
        'audioPath': audioPath,
        'durationMs': duration.inMilliseconds,
        if (year != null) 'year': year,
        if (description != null) 'description': description,
        if (artworkPath != null) 'artworkPath': artworkPath,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as int,
        title: json['title'] as String? ?? 'Unknown title',
        artist: json['artist'] as String? ?? 'Unknown artist',
        album: json['album'] as String? ?? 'Unknown album',
        genre: json['genre'] as String? ?? 'Unknown',
        audioPath: json['audioPath'] as String? ?? '',
        duration: Duration(
          milliseconds: (json['durationMs'] as int?) ?? 0,
        ),
        year: json['year'] as int?,
        description: json['description'] as String?,
        artworkPath: json['artworkPath'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
