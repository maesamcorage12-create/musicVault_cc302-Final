import 'package:flutter/material.dart';

import '../../data/song_catalog.dart';
import '../../models/song.dart';
import '../../widgets/group_detail_screen.dart';

/// Detail screen for one artist in the catalog.
class ArtistDetailScreen extends StatelessWidget {
  const ArtistDetailScreen({super.key, required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context) {
    final List<Song> songs = SongCatalog.all
        .where((Song song) => song.artist == artist)
        .toList(growable: false);
    final Set<String> albums = <String>{
      for (final Song song in songs) song.album,
    };

    return GroupDetailScreen(
      title: artist,
      seed: artist.hashCode,
      songs: songs,
      description: songs.isEmpty
          ? null
          : '${songs.length} ${songs.length == 1 ? 'track' : 'tracks'} · '
              '${albums.length} ${albums.length == 1 ? 'album' : 'albums'}',
    );
  }
}
