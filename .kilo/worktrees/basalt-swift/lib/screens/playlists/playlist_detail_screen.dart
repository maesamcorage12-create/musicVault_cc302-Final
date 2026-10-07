import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/group_detail_screen.dart';
import '../../widgets/vibe_actions.dart';

/// Playlist detail (spec §21).
///
/// Because the playlist can be renamed or deleted while the screen is open,
/// this reads the provider on every build and pops itself if the playlist is
/// gone, rather than holding a stale snapshot.
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final PlaylistProvider provider = context.watch<PlaylistProvider>();
    final playlist = provider.byId(playlistId);

    if (provider.isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (playlist == null) {
      // Deleted from the overflow menu while this screen was open.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold(backgroundColor: Colors.transparent);
    }

    final List<Song> songs = provider.songsFor(playlist);
    final Duration total = Duration(
      seconds: songs.fold<int>(
        0,
        (int sum, Song song) => sum + song.duration.inSeconds,
      ),
    );

    return GroupDetailScreen(
      title: playlist.name,
      seed: playlist.artworkSeed,
      songs: songs,
      description: playlist.description,
      emptyLabel: 'This playlist is empty. Open any song and use '
          '"Add to playlist" to fill it up.',
      subtitleOverride: playlist.songCount == 0
          ? 'Empty playlist'
          : '${playlist.songCount} '
              '${playlist.songCount == 1 ? 'song' : 'songs'} · '
              '${Song.formatDuration(total)}',
      headerTrailing: IconButton(
        onPressed: () => VibeActions.showPlaylistMenu(context, playlist),
        tooltip: 'Playlist options',
        icon: const Icon(Icons.more_vert_rounded),
      ),
    );
  }
}
