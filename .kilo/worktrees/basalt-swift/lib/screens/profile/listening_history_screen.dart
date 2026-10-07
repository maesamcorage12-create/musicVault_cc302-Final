import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_scaffold.dart';
import '../../widgets/page_header.dart';
import '../../widgets/search_song_list.dart';
import '../../widgets/vibe_actions.dart';
import '../search/search_screen.dart';

/// Listening history (spec §23).
///
/// Reads the same data as Home's "Recently Played" — this is the full
/// chronological view with play counts, plus a clear-history action.
class ListeningHistoryScreen extends StatelessWidget {
  const ListeningHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LibraryProvider library = context.watch<LibraryProvider>();
    final StatisticsProvider stats = context.watch<StatisticsProvider>();
    final List<Song> songs = library.listeningHistory(limit: 300);

    return GlassScaffold(
      child: songs.isEmpty
          ? Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const Expanded(
                  child: EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Nothing played yet.',
                    message: 'Find something you like.',
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                AppDimensions.sm,
                AppDimensions.lg,
                AppDimensions.xxl,
              ),
              children: <Widget>[
                PageHeader(
                  title: 'Listening History',
                  subtitle: '${library.history.length} '
                      '${library.history.length == 1 ? 'play' : 'plays'} · '
                      '${stats.statistics.formattedListening} total',
                ),
                GlassCard(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Most replayed is ${stats.mostPlayedSong?.title ?? '—'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _confirmClear(context, library),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
                // Newest first, one row per play (spec §23: Home and Profile read
                // the same underlying history).
                SearchSongList(songs: songs),
                const SizedBox(height: AppDimensions.xl),
                const SectionHeader(
                  title: 'Play counts',
                  subtitle: 'How many times each track was started',
                ),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md,
                    vertical: AppDimensions.sm,
                  ),
                  child: Column(
                    children: <Widget>[
                      for (final MapEntry<Song, int> entry in stats.topSongs(limit: 8))
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimensions.xs,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  entry.key.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                '${entry.value}×',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(color: VibeColors.softPink),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.xl),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    fadeRoute(
                      const GlassScaffold(child: SearchScreen(isStandalone: true)),
                      name: AppRoutes.search,
                    ),
                  ),
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text('BROWSE CATALOG'),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    LibraryProvider library,
  ) async {
    final bool confirmed = await VibeActions.confirmDialog(
          context,
          title: 'Clear listening history?',
          message:
              'Every play record is deleted and your statistics reset. '
              'Favourites and playlists are not affected.',
          confirmLabel: 'Clear history',
          isDestructive: true,
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    await library.clearHistory();
    if (!context.mounted) {
      return;
    }
    VibeActions.showSnack(context, 'Listening history cleared.');
  }
}
