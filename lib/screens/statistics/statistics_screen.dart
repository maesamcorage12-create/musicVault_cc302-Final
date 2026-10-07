import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/song_catalog.dart';
import '../../models/song.dart';
import '../../providers/statistics_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/artwork.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/group_detail_screen.dart';
import '../../widgets/page_header.dart';

/// "YOUR VIBES" (spec §24). Every number here is derived from real activity by
/// `StatisticsProvider` — nothing is hard-coded.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StatisticsProvider stats = context.watch<StatisticsProvider>();

    if (!stats.hasActivity) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg,
          AppDimensions.xl,
          AppDimensions.lg,
          AppDimensions.xxl,
        ),
        children: const <Widget>[
          PageHeader(
            title: 'Your Vibes',
            subtitle: 'Statistics built from what you actually played',
          ),
          EmptyState(
            icon: Icons.insights_rounded,
            title: 'No statistics yet.',
            message:
                'Play a few tracks and your plays, listening time, top song '
                'and top genre appear here.',
          ),
        ],
      );
    }

    final Song? mostPlayed = stats.mostPlayedSong;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.xl,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        const PageHeader(
          title: 'Your Vibes',
          subtitle: 'Statistics built from what you actually played',
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: _BigStat(
                value: '${stats.totalPlays}',
                label: 'Songs Played',
                icon: Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: _BigStat(
                value: stats.statistics.formattedListening,
                label: 'Listening',
                icon: Icons.headphones_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _BigStat(
                value: '${stats.playlistCount}',
                label: 'Playlists',
                icon: Icons.queue_music_rounded,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: _BigStat(
                value: '${stats.favoriteCount}',
                label: 'Favourites',
                icon: Icons.favorite_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.xl),

        const SectionHeader(
          title: 'Top Genre',
          subtitle: 'Where your listening time went',
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              for (final MapEntry<String, int> entry in stats.topGenres(limit: 5))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.sm,
                  ),
                  child: _GenreBar(
                    genre: entry.key,
                    seconds: entry.value,
                    share: stats.genreShare(entry.key),
                    isTop: entry.key == stats.topGenre,
                  ),
                ),
              if (stats.topGenres(limit: 5).isEmpty)
                Text(
                  'No genre data yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.xl),

        const SectionHeader(
          title: 'Most Played',
          subtitle: 'Your repeat offenders',
        ),
        if (mostPlayed != null)
          GlassCard(
            child: Row(
              children: <Widget>[
                Artwork(seed: mostPlayed.id, song: mostPlayed, size: 76),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        mostPlayed.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mostPlayed.artist} · ${mostPlayed.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        '${stats.playsFor(mostPlayed.id)} plays',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: VibeColors.softPink,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => PlayHelper.play(context, <Song>[
                    for (final MapEntry<Song, int> entry
                        in stats.topSongs(limit: 8))
                      entry.key,
                  ]),
                  tooltip: 'Play my top tracks',
                  iconSize: 32,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  color: VibeColors.softPink,
                ),
              ],
            ),
          ),
        const SizedBox(height: AppDimensions.md),
        GlassCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.sm,
          ),
          child: Column(
            children: <Widget>[
              for (final MapEntry<Song, int> entry in stats.topSongs(limit: 6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 26,
                        child: Text(
                          '#${stats.topSongs(limit: 6).indexOf(entry) + 1}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.key.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
                      SizedBox(
                        width: 110,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: entry.value == 0
                                ? 0
                                : entry.value /
                                    (stats.topSongs(limit: 6).first.value == 0
                                        ? 1
                                        : stats.topSongs(limit: 6).first.value),
                            minHeight: 6,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              VibeColors.neonPink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.md),
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

        const SectionHeader(
          title: 'Catalog coverage',
          subtitle: 'How much of VibeVault you have touched',
        ),
        GlassCard(
          child: Column(
            children: <Widget>[
              _CoverageRow(
                label: 'Songs played at least once',
                played: stats.statistics.playCountBySongId.length,
                total: SongCatalog.all.length,
              ),
              const SizedBox(height: AppDimensions.md),
              _CoverageRow(
                label: 'Genres explored',
                played: stats.statistics.listeningSecondsByGenre.length,
                total: SongCatalog.genres.length,
              ),
              const SizedBox(height: AppDimensions.md),
              _CoverageRow(
                label: 'Artists heard',
                played: <String>{
                  for (final int id in stats.statistics.playCountBySongId.keys)
                    if (SongCatalog.byId(id) case final Song song) song.artist,
                }.length,
                total: SongCatalog.artists.length,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusTile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: VibeColors.softPink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 30,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  const _GenreBar({
    required this.genre,
    required this.seconds,
    required this.share,
    required this.isTop,
  });

  final String genre;
  final int seconds;
  final double share;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 66,
          child: Text(
            genre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: isTop ? VibeColors.softPink : VibeColors.white,
                ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isTop ? VibeColors.neonPink : VibeColors.brightBlue,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.md),
        SizedBox(
          width: 56,
          child: Text(
            Song.formatDuration(Duration(seconds: seconds)),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _CoverageRow extends StatelessWidget {
  const _CoverageRow({
    required this.label,
    required this.played,
    required this.total,
  });

  final String label;
  final int played;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double fraction = total == 0 ? 0 : played / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '$played / $total',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: VibeColors.softPink),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: const AlwaysStoppedAnimation<Color>(VibeColors.brightBlue),
          ),
        ),
      ],
    );
  }
}
