import '../models/song.dart';

/// The complete, immutable VibeVault catalog (spec §11: exactly 30 songs).
///
/// `audioPath` values are relative to `assets/`, so `audio/song_01.mp3`
/// resolves to `assets/audio/song_01.mp3`. The audio files are produced by
/// `tool/generate_audio.py`; see that file for the generation rules.
///
/// [catalogSongs] is the canonical lookup used by every provider. Songs referenced
/// only by id (playlists, history, favourites) are resolved through
/// [SongCatalog.byId].
abstract final class SongCatalog {
  static const List<Song> all = <Song>[
    Song(
      id: 1,
      title: 'Midnight Drive',
      artist: 'Neon Harbor',
      album: 'Night Sessions',
      genre: 'Chill',
      audioPath: 'audio/song_01.mp3',
      duration: Duration(milliseconds: 24615),
      year: 2024,
      description: 'Wide-open highways, low beams and a city that never blinks.',
    ),
    Song(
      id: 2,
      title: 'Afterglow',
      artist: 'Luma Fields',
      album: 'Neon Hearts',
      genre: 'Pop',
      audioPath: 'audio/song_02.mp3',
      duration: Duration(milliseconds: 25385),
      year: 2025,
      description: 'The last light of the evening, caught on a warm synth line.',
    ),
    Song(
      id: 3,
      title: 'Dreamscape',
      artist: 'Kiko Waves',
      album: 'Dream State',
      genre: 'Lo-fi',
      audioPath: 'audio/song_03.mp3',
      duration: Duration(milliseconds: 26667),
      year: 2024,
      description: 'Rain on a window, tape hiss, and a melody that never resolves.',
    ),
    Song(
      id: 4,
      title: 'Blue Horizon',
      artist: 'Neon Harbor',
      album: 'Open Skies',
      genre: 'Electronic',
      audioPath: 'audio/song_04.mp3',
      duration: Duration(milliseconds: 26000),
      year: 2025,
      description: 'A four-on-the-floor sunrise above the waterline.',
    ),
    Song(
      id: 5,
      title: 'Pink Static',
      artist: 'Velvet Circuit',
      album: 'Neon Hearts',
      genre: 'Pop',
      audioPath: 'audio/song_05.mp3',
      duration: Duration(milliseconds: 25714),
      year: 2025,
      description: 'Two bright guitars fighting through a wall of radio noise.',
    ),
    Song(
      id: 6,
      title: 'Slow Motion',
      artist: 'Kiko Waves',
      album: 'Night Sessions',
      genre: 'Chill',
      audioPath: 'audio/song_06.mp3',
      duration: Duration(milliseconds: 27429),
      year: 2023,
      description: 'Everything moves, just not quickly enough to miss.',
    ),
    Song(
      id: 7,
      title: 'City Lights',
      artist: 'Neon Harbor',
      album: 'After Dark',
      genre: 'Electronic',
      audioPath: 'audio/song_07.mp3',
      duration: Duration(milliseconds: 25161),
      year: 2024,
      description: 'Midnight traffic rendered as a sequenced pulse.',
    ),
    Song(
      id: 8,
      title: 'Moonlight',
      artist: 'Luma Fields',
      album: 'Dream State',
      genre: 'Lo-fi',
      audioPath: 'audio/song_08.mp3',
      duration: Duration(milliseconds: 28235),
      year: 2023,
      description: 'Half-speed chords and a room full of quiet.',
    ),
    Song(
      id: 9,
      title: 'Electric Bloom',
      artist: 'Velvet Circuit',
      album: 'Neon Hearts',
      genre: 'Electronic',
      audioPath: 'audio/song_09.mp3',
      duration: Duration(milliseconds: 26667),
      year: 2025,
      description: 'Arpeggios that flower open for eight bars, then close again.',
    ),
    Song(
      id: 10,
      title: 'Velvet Rain',
      artist: 'Kiko Waves',
      album: 'Night Sessions',
      genre: 'Chill',
      audioPath: 'audio/song_10.mp3',
      duration: Duration(milliseconds: 25946),
      year: 2024,
      description: 'A slow drizzle of keys over a patient, rolling bass.',
    ),
    Song(
      id: 11,
      title: 'Orbit',
      artist: 'Satellite Youth',
      album: 'Open Skies',
      genre: 'Electronic',
      audioPath: 'audio/song_11.mp3',
      duration: Duration(milliseconds: 25574),
      year: 2025,
      description: 'Built for the three minutes between takeoff and weightlessness.',
    ),
    Song(
      id: 12,
      title: 'Soft Focus',
      artist: 'Kiko Waves',
      album: 'Dream State',
      genre: 'Lo-fi',
      audioPath: 'audio/song_12.mp3',
      duration: Duration(milliseconds: 27429),
      year: 2023,
      description: 'Everything slightly blurred, on purpose.',
    ),
    Song(
      id: 13,
      title: 'Night Bloom',
      artist: 'Luma Fields',
      album: 'After Dark',
      genre: 'Pop',
      audioPath: 'audio/song_13.mp3',
      duration: Duration(milliseconds: 26400),
      year: 2024,
      description: 'A chorus that arrives like a streetlight switching on.',
    ),
    Song(
      id: 14,
      title: 'Gravity',
      artist: 'Satellite Youth',
      album: 'Open Skies',
      genre: 'Electronic',
      audioPath: 'audio/song_14.mp3',
      duration: Duration(milliseconds: 26441),
      year: 2025,
      description: 'Weightless pads held together by one very low sine wave.',
    ),
    Song(
      id: 15,
      title: 'Heartbeat',
      artist: 'Velvet Circuit',
      album: 'Neon Hearts',
      genre: 'Pop',
      audioPath: 'audio/song_15.mp3',
      duration: Duration(milliseconds: 26667),
      year: 2025,
      description: 'Kick drum and kickback, in that order.',
    ),
    Song(
      id: 16,
      title: 'Cloud Nine',
      artist: 'Kiko Waves',
      album: 'Dream State',
      genre: 'Lo-fi',
      audioPath: 'audio/song_16.mp3',
      duration: Duration(milliseconds: 29091),
      year: 2023,
      description: 'The slowest thing in the catalog, on purpose.',
    ),
    Song(
      id: 17,
      title: 'Night Runner',
      artist: 'Neon Harbor',
      album: 'After Dark',
      genre: 'Electronic',
      audioPath: 'audio/song_17.mp3',
      duration: Duration(milliseconds: 26250),
      year: 2025,
      description: 'Sixteen bars of forward motion and no brakes.',
    ),
    Song(
      id: 18,
      title: 'Golden Hour',
      artist: 'Luma Fields',
      album: 'Open Skies',
      genre: 'Chill',
      audioPath: 'audio/song_18.mp3',
      duration: Duration(milliseconds: 25263),
      year: 2024,
      description: 'Warm pads for the twenty minutes before the sky gives up.',
    ),
    Song(
      id: 19,
      title: 'Static Love',
      artist: 'Velvet Circuit',
      album: 'Neon Hearts',
      genre: 'Pop',
      audioPath: 'audio/song_19.mp3',
      duration: Duration(milliseconds: 24906),
      year: 2025,
      description: 'A love letter written on a broken television.',
    ),
    Song(
      id: 20,
      title: 'Ocean Eyes',
      artist: 'Kiko Waves',
      album: 'Night Sessions',
      genre: 'Chill',
      audioPath: 'audio/song_20.mp3',
      duration: Duration(milliseconds: 26667),
      year: 2024,
      description: 'Tidal swells of reverb under a very patient lead line.',
    ),
    Song(
      id: 21,
      title: 'Parallel',
      artist: 'Satellite Youth',
      album: 'After Dark',
      genre: 'Electronic',
      audioPath: 'audio/song_21.mp3',
      duration: Duration(milliseconds: 25161),
      year: 2024,
      description: 'Two lines running the same distance, never meeting.',
    ),
    Song(
      id: 22,
      title: 'Falling Slowly',
      artist: 'Kiko Waves',
      album: 'Dream State',
      genre: 'Lo-fi',
      audioPath: 'audio/song_22.mp3',
      duration: Duration(milliseconds: 28235),
      year: 2023,
      description: 'A descent with no floor to land on.',
    ),
    Song(
      id: 23,
      title: 'Polaroid',
      artist: 'Luma Fields',
      album: 'Neon Hearts',
      genre: 'Pop',
      audioPath: 'audio/song_23.mp3',
      duration: Duration(milliseconds: 25882),
      year: 2025,
      description: 'Sun-faded and slightly out of focus, like the picture frame.',
    ),
    Song(
      id: 24,
      title: 'Rainy Streets',
      artist: 'Neon Harbor',
      album: 'Night Sessions',
      genre: 'Chill',
      audioPath: 'audio/song_24.mp3',
      duration: Duration(milliseconds: 25600),
      year: 2024,
      description: 'Wet asphalt, reflected signs, and a slow walk home.',
    ),
    Song(
      id: 25,
      title: 'Starlight',
      artist: 'Satellite Youth',
      album: 'Open Skies',
      genre: 'Electronic',
      audioPath: 'audio/song_25.mp3',
      duration: Duration(milliseconds: 26000),
      year: 2025,
      description: 'A shimmering pad stack for the drive out of town.',
    ),
    Song(
      id: 26,
      title: 'Daydream',
      artist: 'Kiko Waves',
      album: 'Dream State',
      genre: 'Lo-fi',
      audioPath: 'audio/song_26.mp3',
      duration: Duration(milliseconds: 30000),
      year: 2023,
      description: 'Thirty seconds of nothing happening, beautifully.',
    ),
    Song(
      id: 27,
      title: 'Wildfire',
      artist: 'Velvet Circuit',
      album: 'After Dark',
      genre: 'Pop',
      audioPath: 'audio/song_27.mp3',
      duration: Duration(milliseconds: 26182),
      year: 2025,
      description: 'The one on the album with the fastest tempo.',
    ),
    Song(
      id: 28,
      title: 'Lucid',
      artist: 'Kiko Waves',
      album: 'Dream State',
      genre: 'Lo-fi',
      audioPath: 'audio/song_28.mp3',
      duration: Duration(milliseconds: 27429),
      year: 2024,
      description: 'Waking up inside a track that never stopped playing.',
    ),
    Song(
      id: 29,
      title: 'Neon Sky',
      artist: 'Neon Harbor',
      album: 'Neon Hearts',
      genre: 'Electronic',
      audioPath: 'audio/song_29.mp3',
      duration: Duration(milliseconds: 25574),
      year: 2025,
      description: 'The title track energy of a late arcade.',
    ),
    Song(
      id: 30,
      title: 'Last Train Home',
      artist: 'Luma Fields',
      album: 'Night Sessions',
      genre: 'Chill',
      audioPath: 'audio/song_30.mp3',
      duration: Duration(milliseconds: 26301),
      year: 2024,
      description: 'Last song of the night, every night.',
    ),
  ];

  static final Map<int, Song> _byId = <int, Song>{
    for (final Song song in all) song.id: song,
  };

  static Song? byId(int id) => _byId[id];

  /// Resolves a list of ids to songs, dropping ids that no longer exist.
  static List<Song> resolve(Iterable<int> ids) {
    final List<Song> result = <Song>[];
    for (final int id in ids) {
      final Song? song = _byId[id];
      if (song != null) {
        result.add(song);
      }
    }
    return result;
  }

  /// Distinct artists, alphabetical.
  static List<String> get artists {
    final Set<String> names = all.map((Song s) => s.artist).toSet();
    final List<String> sorted = names.toList()..sort();
    return sorted;
  }

  /// Distinct albums, alphabetical.
  static List<String> get albums {
    final Set<String> names = all.map((Song s) => s.album).toSet();
    final List<String> sorted = names.toList()..sort();
    return sorted;
  }

  /// Distinct genres, alphabetical.
  static List<String> get genres {
    final Set<String> names = all.map((Song s) => s.genre).toSet();
    final List<String> sorted = names.toList()..sort();
    return sorted;
  }

  /// Song id lookup keyed for the statistics screen's chart widgets.
  static Map<int, int> get secondsById => <int, int>{
        for (final Song song in all) song.id: song.duration.inSeconds,
      };

  /// Default playlists shown under "Made For You" (spec §17).
  static List<PlaylistSeed> get curatedPlaylists => const <PlaylistSeed>[
        PlaylistSeed(
          title: 'Night Vibes',
          description: 'Late-night drive music',
          genre: 'Chill',
        ),
        PlaylistSeed(
          title: 'Study Loop',
          description: 'Low-key beats for deep work',
          genre: 'Lo-fi',
        ),
        PlaylistSeed(
          title: 'Energy Boost',
          description: 'Fast tempo for the gym',
          genre: 'Electronic',
        ),
        PlaylistSeed(
          title: 'Feel Good',
          description: 'Bright, catchy, loud',
          genre: 'Pop',
        ),
      ];
}

/// Definition of a read-only curated mix. Seeded playlists are real, persisted
/// `Playlist` objects created on first launch, so they behave exactly like user
/// playlists (and can be renamed or deleted).
class PlaylistSeed {
  const PlaylistSeed({
    required this.title,
    required this.description,
    required this.genre,
  });

  final String title;
  final String description;

  /// When set, the mix contains every catalog song of that genre.
  final String? genre;
}
