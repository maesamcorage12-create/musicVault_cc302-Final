import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_dimensions.dart';
import 'glass_card.dart';
import 'group_detail_screen.dart';
import 'song_tile.dart';
import 'vibe_actions.dart';

/// Glass list of song rows with favourite hearts and per-track overflow menus.
///
/// Used by Search, Liked Songs, Album detail and Playlist detail so every list
/// behaves identically.
class SearchSongList extends StatelessWidget {
  const SearchSongList({super.key, required this.songs, this.onRemove});

  final List<Song> songs;

  /// When provided, each row gets a "remove" button (playlist detail).
  final void Function(Song song)? onRemove;

  @override
  Widget build(BuildContext context) {
    final LibraryProvider library = context.watch<LibraryProvider>();
    final PlayerProvider player = context.watch<PlayerProvider>();

    if (songs.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      child: Column(
        children: <Widget>[
          for (final Song song in songs)
            SongTile(
              song: song,
              dense: true,
              isPlaying: player.currentSong?.id == song.id && player.isPlaying,
              isFavorite: library.isFavorite(song.id),
              onToggleFavorite: () => library.toggleFavorite(song.id),
              onTap: () => PlayHelper.play(context, songs, startAt: song),
              actions: <Widget>[
                IconButton(
                  onPressed: () =>
                      VibeActions.showSongActions(context, song, playContext: songs),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'More',
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: () => onRemove!(song),
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove',
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
