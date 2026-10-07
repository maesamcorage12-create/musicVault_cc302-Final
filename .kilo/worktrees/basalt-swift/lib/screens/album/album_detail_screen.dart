import 'package:flutter/material.dart';

import '../../data/song_catalog.dart';
import '../../models/song.dart';
import '../../widgets/group_detail_screen.dart';

/// Detail screen for one album in the catalog.
class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({super.key, required this.album});

  final String album;

  @override
  Widget build(BuildContext context) {
    final List<Song> songs = SongCatalog.all
        .where((Song song) => song.album == album)
        .toList(growable: false);
    final String artists = <String>{
      for (final Song song in songs) song.artist,
    }.join(', ');

    return GroupDetailScreen(
      title: album,
      seed: album.hashCode,
      songs: songs,
      description: songs.isEmpty ? null : 'by $artists',
    );
  }
}
