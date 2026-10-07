import '../models/song.dart';

/// The complete VibeVault catalog: 30 OPM and English tracks.
///
/// `audioPath` values are relative to `assets/`, so `audio/song_01.mp3`
/// resolves to `assets/audio/song_01.mp3`.
///
/// `artworkPath` values are relative to `assets/`, so `covers/song_01.jpg`
/// resolves to `assets/covers/song_01.jpg`.
///
/// [catalogSongs] is the canonical lookup used by every provider. Songs
/// referenced by id (playlists, history, favourites) are resolved through
/// [SongCatalog.byId].
abstract final class SongCatalog {
  static const List<Song> all = <Song>[
    Song(
      id: 1,
      title: 'Lihim',
      artist: 'Arthur Miguel',
      album: 'Lihim',
      genre: 'Pop',
      audioPath: 'audio/song_01.mp3',
      artworkPath: 'covers/song_01.jpg',
      duration: Duration(milliseconds: 246596),
      year: 2023,
      description: 'A heartfelt ballad exploring the beauty of hidden feelings.',
    ),
    Song(
      id: 2,
      title: 'Leaves',
      artist: 'Ben&Ben',
      album: 'Leaves',
      genre: 'Indie Pop',
      audioPath: 'audio/song_02.mp3',
      artworkPath: 'covers/song_02.jpg',
      duration: Duration(milliseconds: 311458),
      year: 2024,
      description: 'A contemplative piece about letting go and new beginnings.',
    ),
    Song(
      id: 3,
      title: 'Maybe The Night',
      artist: 'Ben&Ben',
      album: 'Maybe The Night',
      genre: 'Indie Pop',
      audioPath: 'audio/song_03.mp3',
      artworkPath: 'covers/song_03.jpg',
      duration: Duration(milliseconds: 217260),
      year: 2024,
      description: 'An introspective track about the uncertainties of love.',
    ),
    Song(
      id: 4,
      title: 'Araw-Araw',
      artist: 'Ben&Ben',
      album: 'Araw-Araw',
      genre: 'Indie Pop',
      audioPath: 'audio/song_04.mp3',
      artworkPath: 'covers/song_04.jpg',
      duration: Duration(milliseconds: 329012),
      year: 2025,
      description: 'A daily ode to love and perseverance.',
    ),
    Song(
      id: 5,
      title: 'Lifetime (Reimagined)',
      artist: 'Ben&Ben',
      album: 'Lifetime',
      genre: 'Indie Pop',
      audioPath: 'audio/song_05.mp3',
      artworkPath: 'covers/song_05.jpg',
      duration: Duration(milliseconds: 278021),
      year: 2026,
      description: 'A reimagined version of their timeless track.',
    ),
    Song(
      id: 6,
      title: 'Pagtingin',
      artist: 'Ben&Ben',
      album: 'Pagtingin',
      genre: 'Indie Pop',
      audioPath: 'audio/song_06.mp3',
      artworkPath: 'covers/song_06.jpg',
      duration: Duration(milliseconds: 240300),
      year: 2023,
      description: 'An OPM anthem about longing and heartfelt emotions.',
    ),
    Song(
      id: 7,
      title: 'Paninindigan Kita',
      artist: 'Ben&Ben',
      album: 'Pebble House',
      genre: 'Indie Pop',
      audioPath: 'audio/song_07.mp3',
      artworkPath: 'covers/song_07.jpg',
      duration: Duration(milliseconds: 309786),
      year: 2023,
      description: 'Standing firm in love despite the chaos around.',
    ),
    Song(
      id: 8,
      title: 'Sa Susunod na Habang Buhay',
      artist: 'Ben&Ben',
      album: 'Sa Susunod na Habang Buhay',
      genre: 'Indie Pop',
      audioPath: 'audio/song_08.mp3',
      artworkPath: 'covers/song_08.jpg',
      duration: Duration(milliseconds: 280056),
      year: 2024,
      description: 'A promise of love beyond this lifetime.',
    ),
    Song(
      id: 9,
      title: 'The Ones We Once Loved',
      artist: 'Ben&Ben',
      album: 'The Pebble House',
      genre: 'Indie Pop',
      audioPath: 'audio/song_09.mp3',
      artworkPath: 'covers/song_09.jpg',
      duration: Duration(milliseconds: 276024),
      year: 2024,
      description: 'Remembering the love that shaped who we are today.',
    ),
    Song(
      id: 10,
      title: 'Estranghero',
      artist: 'Cup of Joe',
      album: 'Estranghero',
      genre: 'OPM',
      audioPath: 'audio/song_10.mp3',
      artworkPath: 'covers/song_10.jpg',
      duration: Duration(milliseconds: 184464),
      year: 2023,
      description: 'A modern OPM hit about distance and longing.',
    ),
    Song(
      id: 11,
      title: 'Pahina',
      artist: 'Cup of Joe',
      album: 'Pahina',
      genre: 'OPM',
      audioPath: 'audio/song_11.mp3',
      artworkPath: 'covers/song_11.jpg',
      duration: Duration(milliseconds: 250723),
      year: 2024,
      description: 'Exploring themes of vulnerability and emotional strength.',
    ),
    Song(
      id: 12,
      title: 'Patutunguhan',
      artist: 'Cup of Joe',
      album: 'Patutunguhan',
      genre: 'OPM',
      audioPath: 'audio/song_12.mp3',
      artworkPath: 'covers/song_12.jpg',
      duration: Duration(milliseconds: 252056),
      year: 2023,
      description: 'A journey toward a destination, both literal and metaphorical.',
    ),
    Song(
      id: 13,
      title: 'Tingin',
      artist: 'Cup of Joe ft. Janine Teñoso',
      album: 'Tingin',
      genre: 'OPM',
      audioPath: 'audio/song_13.mp3',
      artworkPath: 'covers/song_13.jpg',
      duration: Duration(milliseconds: 243696),
      year: 2024,
      description: 'A collaborative track about seeing love through another\'s eyes.',
    ),
    Song(
      id: 14,
      title: 'Bulong',
      artist: 'December Avenue',
      album: 'Bulong',
      genre: 'OPM Rock',
      audioPath: 'audio/song_14.mp3',
      artworkPath: 'covers/song_14.jpg',
      duration: Duration(milliseconds: 270498),
      year: 2022,
      description: 'A powerful OPM rock anthem about secrets and truth.',
    ),
    Song(
      id: 15,
      title: 'Dahan',
      artist: 'December Avenue',
      album: 'Dahan',
      genre: 'OPM Rock',
      audioPath: 'audio/song_15.mp3',
      artworkPath: 'covers/song_15.jpg',
      duration: Duration(milliseconds: 297561),
      year: 2023,
      description: 'A gentle plea to take things slow in love.',
    ),
    Song(
      id: 16,
      title: 'Eroplanong Papel',
      artist: 'December Avenue',
      album: 'Eroplanong Papel',
      genre: 'OPM Rock',
      audioPath: 'audio/song_16.mp3',
      artworkPath: 'covers/song_16.jpg',
      duration: Duration(milliseconds: 311510),
      year: 2022,
      description: 'A metaphorical track about fragile dreams.',
    ),
    Song(
      id: 17,
      title: 'Huling Sandali',
      artist: 'December Avenue',
      album: 'Huling Sandali',
      genre: 'OPM Rock',
      audioPath: 'audio/song_17.mp3',
      artworkPath: 'covers/song_17.jpg',
      duration: Duration(milliseconds: 343171),
      year: 2023,
      description: 'Capturing the last moments of a relationship.',
    ),
    Song(
      id: 18,
      title: 'Kahit Di Mo Alam',
      artist: 'December Avenue',
      album: 'Kahit Di Mo Alam',
      genre: 'OPM Rock',
      audioPath: 'audio/song_18.mp3',
      artworkPath: 'covers/song_18.jpg',
      duration: Duration(milliseconds: 282514),
      year: 2022,
      description: 'A heartfelt song about loving without certainty.',
    ),
    Song(
      id: 19,
      title: 'Kung \'Di Rin Lang Ikaw',
      artist: 'December Avenue ft. Moira Dela Torre',
      album: 'Kung \'Di Rin Lang Ikaw',
      genre: 'OPM Rock',
      audioPath: 'audio/song_19.mp3',
      artworkPath: 'covers/song_19.jpg',
      duration: Duration(milliseconds: 262870),
      year: 2023,
      description: 'A duet about the pain of parting ways.',
    ),
    Song(
      id: 20,
      title: 'Sa Ngalan Ng Pag-Ibig',
      artist: 'December Avenue',
      album: 'Sa Ngalan Ng Pag-Ibig',
      genre: 'OPM Rock',
      audioPath: 'audio/song_20.mp3',
      artworkPath: 'covers/song_20.jpg',
      duration: Duration(milliseconds: 273293),
      year: 2023,
      description: 'A passionate ode to love and devotion.',
    ),
    Song(
      id: 21,
      title: 'Saksi Ang Langit',
      artist: 'December Avenue',
      album: 'Saksi Ang Langit',
      genre: 'OPM Rock',
      audioPath: 'audio/song_21.mp3',
      artworkPath: 'covers/song_21.jpg',
      duration: Duration(milliseconds: 271961),
      year: 2024,
      description: 'A powerful track about the sky bearing witness to love.',
    ),
    Song(
      id: 22,
      title: 'Ikaw Pa Rin Ang Pipiliin Ko',
      artist: 'Cup of Joe',
      album: 'Ikaw Pa Rin Ang Pipiliin Ko',
      genre: 'OPM',
      audioPath: 'audio/song_22.mp3',
      artworkPath: 'covers/song_22.jpg',
      duration: Duration(milliseconds: 300350),
      year: 2024,
      description: 'Even among a thousand options, you remain my choice.',
    ),
    Song(
      id: 23,
      title: 'Infinitely Falling',
      artist: 'Fly By Midnight',
      album: 'Infinitely Falling',
      genre: 'Pop',
      audioPath: 'audio/song_23.mp3',
      artworkPath: 'covers/song_23.jpg',
      duration: Duration(milliseconds: 195082),
      year: 2023,
      description: 'A dreamy pop track about endless love.',
    ),
    Song(
      id: 24,
      title: 'Kathang Isip',
      artist: 'Ben&Ben',
      album: 'Pebble House',
      genre: 'Indie Pop',
      audioPath: 'audio/song_24.mp3',
      artworkPath: 'covers/song_24.jpg',
      duration: Duration(milliseconds: 318851),
      year: 2023,
      description: 'A beautiful song about thoughts of you.',
    ),
    Song(
      id: 25,
      title: 'Mananatili',
      artist: 'Cup of Joe',
      album: 'Mananatili',
      genre: 'OPM',
      audioPath: 'audio/song_25.mp3',
      artworkPath: 'covers/song_25.jpg',
      duration: Duration(milliseconds: 245264),
      year: 2023,
      description: 'A promise to stay despite the distance.',
    ),
    Song(
      id: 26,
      title: 'Misteryoso',
      artist: 'Cup of Joe',
      album: 'Misteryoso',
      genre: 'OPM',
      audioPath: 'audio/song_26.mp3',
      artworkPath: 'covers/song_26.jpg',
      duration: Duration(milliseconds: 237453),
      year: 2023,
      description: 'A mysterious love that keeps you wondering.',
    ),
    Song(
      id: 27,
      title: 'Multo',
      artist: 'Cup of Joe',
      album: 'Multo',
      genre: 'OPM',
      audioPath: 'audio/song_27.mp3',
      artworkPath: 'covers/song_27.jpg',
      duration: Duration(milliseconds: 345260),
      year: 2024,
      description: 'A hauntingly beautiful track about supernatural love.',
    ),
    Song(
      id: 28,
      title: 'Nag-iisang Muli',
      artist: 'Cup of Joe',
      album: 'Nag-iisang Muli',
      genre: 'OPM',
      audioPath: 'audio/song_28.mp3',
      artworkPath: 'covers/song_28.jpg',
      duration: Duration(milliseconds: 325846),
      year: 2024,
      description: 'A plea for another chance at love.',
    ),
    Song(
      id: 29,
      title: 'Ride Home',
      artist: 'Ben&Ben',
      album: 'Ride Home',
      genre: 'Indie Pop',
      audioPath: 'audio/song_29.mp3',
      artworkPath: 'covers/song_29.jpg',
      duration: Duration(milliseconds: 326922),
      year: 2022,
      description: 'A journey of love and coming home.',
    ),
    Song(
      id: 30,
      title: 'Sagada',
      artist: 'Cup of Joe',
      album: 'Sagada',
      genre: 'OPM',
      audioPath: 'audio/song_30.mp3',
      artworkPath: 'covers/song_30.jpg',
      duration: Duration(milliseconds: 263184),
      year: 2023,
      description: 'A love story set against the backdrop of Sagada.',
    ),
  ];

  static final Map<int, Song> _byId = <int, Song>{
    for (final Song song in all) song.id: song,
  };

  static Song? byId(int id) => _byId[id];

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

  static List<String> get artists {
    final Set<String> names = all.map((Song s) => s.artist).toSet();
    final List<String> sorted = names.toList()..sort();
    return sorted;
  }

  static List<String> get albums {
    final Set<String> names = all.map((Song s) => s.album).toSet();
    final List<String> sorted = names.toList()..sort();
    return sorted;
  }

  static List<String> get genres {
    final Set<String> names = all.map((Song s) => s.genre).toSet();
    final List<String> sorted = names.toList()..sort();
    return sorted;
  }

  static Map<int, int> get secondsById => <int, int>{
        for (final Song song in all) song.id: song.duration.inSeconds,
      };

  static List<PlaylistSeed> get curatedPlaylists => const <PlaylistSeed>[
        PlaylistSeed(
          id: 1,
          title: 'OPM Love Songs',
          description: 'The best OPM love anthems in one place',
          songIds: <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        ),
        PlaylistSeed(
          id: 2,
          title: 'December Avenue Essentials',
          description: 'All the hits from the kings of OPM rock',
          songIds: <int>[14, 15, 16, 17, 18, 19, 20, 21],
        ),
        PlaylistSeed(
          id: 3,
          title: 'Cup of Joe Collection',
          description: 'The complete Cup of Joe discography',
          songIds: <int>[10, 11, 12, 13, 22, 25, 26, 27, 28, 30],
        ),
        PlaylistSeed(
          id: 4,
          title: 'Ben&Ben Anthology',
          description: 'Every Ben&Ben track, curated',
          songIds: <int>[2, 3, 4, 5, 6, 7, 8, 9, 24, 29],
        ),
      ];
}

/// Definition of a read-only curated mix. Seeded playlists are real, persisted
/// `Playlist` objects created on first launch, so they behave exactly like user
/// playlists (and can be renamed or deleted).
class PlaylistSeed {
  const PlaylistSeed({
    required this.id,
    required this.title,
    required this.description,
    required this.songIds,
  });

  final int id;
  final String title;
  final String description;
  final List<int> songIds;
}
