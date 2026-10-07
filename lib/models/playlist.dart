/// A user-created playlist. Songs are stored as catalog ids so a playlist keeps
/// working even if catalog metadata is edited later.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.description = '',
    this.updatedAt,
    this.artworkSeed = 0,
  });

  final String id;
  final String name;
  final String description;
  final List<int> songIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Seed for the generated gradient cover.
  final int artworkSeed;

  int get songCount => songIds.length;
  bool get isEmpty => songIds.isEmpty;

  /// Caller passes in a lookup so the model stays free of catalog knowledge.
  int totalSeconds({required Map<int, int> secondsById}) {
    int total = 0;
    for (final int id in songIds) {
      total += secondsById[id] ?? 0;
    }
    return total;
  }

  Playlist copyWith({
    String? name,
    String? description,
    List<int>? songIds,
    DateTime? updatedAt,
    int? artworkSeed,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      songIds: List<int>.unmodifiable(songIds ?? this.songIds),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      artworkSeed: artworkSeed ?? this.artworkSeed,
    );
  }

  /// Adds [songId] unless already present; returns `true` when it changed.
  Playlist withSong(int songId) {
    if (songIds.contains(songId)) {
      return this;
    }
    return copyWith(
      songIds: <int>[...songIds, songId],
      updatedAt: DateTime.now(),
    );
  }

  /// Removes [songId]; returns `true` when it changed.
  Playlist withoutSong(int songId) {
    if (!songIds.contains(songId)) {
      return this;
    }
    return copyWith(
      songIds: <int>[...songIds.where((int id) => id != songId)],
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'description': description,
        'songIds': songIds,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'artworkSeed': artworkSeed,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawIds = json['songIds'] as List<dynamic>? ?? const [];
    return Playlist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled playlist',
      description: json['description'] as String? ?? '',
      songIds: List<int>.unmodifiable(
        rawIds.whereType<int>(),
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      artworkSeed: (json['artworkSeed'] as int?) ?? 0,
    );
  }
}
