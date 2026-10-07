import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/group_detail_screen.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_header.dart';
import '../../widgets/search_song_list.dart';
import '../../widgets/vibe_actions.dart';

/// Favourites (spec §20). Favourites are persisted per account, so closing the
/// app never clears them.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LibraryProvider library = context.watch<LibraryProvider>();

    if (library.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.xl),
        child: SkeletonList(itemCount: 6),
      );
    }

    final List<Song> songs = library.favoriteSongs;

    if (songs.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.xl,
          AppDimensions.lg,
          AppDimensions.xxl,
        ),
        children: const <Widget>[
          PageHeader(
            title: 'Favourites',
            subtitle: 'The tracks you saved with a tap on the heart',
          ),
          EmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No liked songs yet.',
            message: 'Tap the heart on a song to save it here.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.xl,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        PageHeader(
          title: 'Favourites',
          subtitle:
              '${songs.length} ${songs.length == 1 ? 'track' : 'tracks'} saved',
        ),
        GlassCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Liked Songs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${songs.length} '
                      '${songs.length == 1 ? 'track' : 'tracks'} · '
                      '${Song.formatDuration(Duration(seconds: songs.fold<int>(0, (int sum, Song s) => sum + s.duration.inSeconds)))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => PlayHelper.play(context, songs),
                tooltip: 'Play favourites',
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              const SizedBox(width: AppDimensions.sm),
              IconButton.filled(
                onPressed: () => PlayHelper.shuffle(context, songs),
                tooltip: 'Shuffle favourites',
                icon: const Icon(Icons.shuffle_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        SearchSongList(songs: songs),
        const SizedBox(height: AppDimensions.xl),
        OutlinedButton.icon(
          onPressed: () async {
            final bool confirmed = await VibeActions.confirmDialog(
                  context,
                  title: 'Clear all favourites?',
                  message:
                      'This removes ${songs.length} '
                      '${songs.length == 1 ? 'favourite' : 'favourites'} from '
                      'this account.',
                  confirmLabel: 'Clear',
                  isDestructive: true,
                ) ??
                false;
            if (!confirmed || !context.mounted) {
              return;
            }
            for (final Song song in songs) {
              await library.toggleFavorite(song.id);
            }
            if (!context.mounted) {
              return;
            }
            VibeActions.showSnack(context, 'Favourites cleared.');
          },
          icon: const Icon(Icons.heart_broken_outlined, size: 18),
          label: const Text('CLEAR ALL FAVOURITES'),
        ),
      ],
    );
  }
}
