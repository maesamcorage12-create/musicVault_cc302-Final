import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/song.dart';
import '../../providers/playlist_provider.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/group_detail_screen.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_header.dart';
import '../../widgets/playlist_card.dart';
import '../../widgets/vibe_actions.dart';
import 'playlist_detail_screen.dart';

/// All playlists (spec §21) — the dedicated Playlists destination. The Library
/// screen shows the same data in a different arrangement.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlaylistProvider playlists = context.watch<PlaylistProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.xl,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        PageHeader(
          title: 'Playlists',
          subtitle: playlists.isEmpty
              ? 'Nothing here yet'
              : '${playlists.playlistCount} '
                  '${playlists.playlistCount == 1 ? 'playlist' : 'playlists'} '
                  '· saved on this device',
          trailing: FilledButton.icon(
            onPressed: () => VibeActions.showPlaylistEditor(
              context,
              suggestedName: 'My Playlist',
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New'),
          ),
        ),
        if (playlists.isLoading)
          const SkeletonList(itemCount: 5)
        else if (playlists.isEmpty)
          EmptyState(
            icon: Icons.queue_music_rounded,
            title: 'Your library is empty.',
            message:
                'Create your first playlist and start building your vibe.',
            actionLabel: '+ CREATE PLAYLIST',
            onAction: () => VibeActions.showPlaylistEditor(
              context,
              suggestedName: 'My Playlist',
            ),
          )
        else ...<Widget>[
          _BulkPlayBar(
            songs: <Song>[
              for (final playlist in playlists.playlists)
                ...playlists.songsFor(playlist),
            ],
          ),
          for (final playlist in playlists.playlists)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: PlaylistRowTile(
                playlist: playlist,
                subtitleOverride: _subtitle(playlist.songCount, playlist.description),
                onTap: () => Navigator.of(context).push(
                  fadeRoute(
                    PlaylistDetailScreen(playlistId: playlist.id),
                    name: AppRoutes.playlist,
                  ),
                ),
                onPlay: playlists.songsFor(playlist).isEmpty
                    ? null
                    : () => PlayHelper.play(context, playlists.songsFor(playlist)),
                onMore: () => VibeActions.showPlaylistMenu(context, playlist),
              ),
            ),
        ],
      ],
    );
  }

  static String _subtitle(int count, String description) {
    final String songs = count == 0
        ? 'Empty playlist'
        : '$count ${count == 1 ? 'song' : 'songs'}';
    if (description.isEmpty) {
      return songs;
    }
    return '$songs · $description';
  }
}

/// Play-all / shuffle-all bar shown once at least one playlist exists.
class _BulkPlayBar extends StatelessWidget {
  const _BulkPlayBar({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.lg),
      child: Row(
        children: <Widget>[
          Expanded(
            child: FilledButton.icon(
              onPressed: songs.isEmpty
                  ? null
                  : () => PlayHelper.play(context, songs),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('PLAY ALL'),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: songs.isEmpty
                  ? null
                  : () => PlayHelper.shuffle(context, songs),
              icon: const Icon(Icons.shuffle_rounded, size: 18),
              label: const Text('SHUFFLE'),
            ),
          ),
        ],
      ),
    );
  }
}
