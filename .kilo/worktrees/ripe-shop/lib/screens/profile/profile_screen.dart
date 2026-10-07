import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/shell/app_shell.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/artwork.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/vibe_actions.dart';
import 'listening_history_screen.dart';

/// Profile (spec §25): identity, headline numbers, top song / genre and
/// navigation into history, favourites, playlists, settings and logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final StatisticsProvider stats = context.watch<StatisticsProvider>();
    final LibraryProvider library = context.watch<LibraryProvider>();
    final Song? topSong = stats.mostPlayedSong;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.xl,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        PageHeader(
          title: 'Profile',
          subtitle: 'Your vault at a glance',
          trailing: IconButton(
            onPressed: () => VibeActions.confirmLogout(context),
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ),
        GlassCard(
          intensity: GlassIntensity.strong,
          child: Row(
            children: <Widget>[
              Avatar(
                initials: auth.user?.initials ?? '?',
                seed: auth.user?.avatarSeed ?? 0,
                size: 84,
              ),
              const SizedBox(width: AppDimensions.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      auth.user?.username ?? 'Listener',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.user?.email ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusChip),
                        border: Border.all(color: VibeColors.glassBorder(1.2)),
                      ),
                      child: Text(
                        'Local account',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatCard(
                label: 'Songs played',
                value: '${stats.totalPlays}',
                icon: Icons.play_arrow_rounded,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: _StatCard(
                label: 'Listening',
                value: stats.statistics.formattedListening,
                icon: Icons.headphones_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: <Widget>[
            Expanded(
              child: _StatCard(
                label: 'Playlists',
                value: '${stats.playlistCount}',
                icon: Icons.queue_music_rounded,
              ),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: _StatCard(
                label: 'Favourites',
                value: '${stats.favoriteCount}',
                icon: Icons.favorite_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.xl),

        const SectionHeader(
          title: 'Your top',
          subtitle: 'Derived from your real listening activity',
        ),
        if (!stats.hasActivity)
          GlassCard(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.insights_outlined,
                  color: VibeColors.mutedText,
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Text(
                    'Play a few tracks and your top song and genre appear here.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else ...<Widget>[
          GlassCard(
            child: Row(
              children: <Widget>[
                Artwork(
                  seed: topSong?.id ?? 0,
                  song: topSong,
                  size: 62,
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Most played',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        topSong?.title ?? 'Nothing yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        topSong == null
                            ? ''
                            : '${stats.playsFor(topSong.id)} plays · ${topSong.artist}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          GlassCard(
            child: Row(
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: VibeColors.primaryGradient,
                  ),
                  child: Center(
                    child: Text(
                      stats.topGenre ?? '—',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Top genre',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stats.topGenre ?? 'Nothing yet',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      if (stats.topGenre != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: stats.genreShare(stats.topGenre!),
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              VibeColors.neonPink,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.xl),

        const SectionHeader(title: 'Manage'),
        _ActionTile(
          icon: Icons.history_rounded,
          title: 'Listening History',
          subtitle: library.history.isEmpty
              ? 'Nothing played yet'
              : '${library.history.length} '
                  '${library.history.length == 1 ? 'play' : 'plays'} recorded',
          onTap: () => Navigator.of(context).push(
            fadeRoute(
              const ListeningHistoryScreen(),
              name: AppRoutes.listeningHistory,
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.favorite_rounded,
          title: 'Favourites',
          subtitle: '${library.favoriteCount} '
              '${library.favoriteCount == 1 ? 'track' : 'tracks'} saved',
          onTap: () => ShellNavigatorScope.of(context)?.goTo(ShellDestination.favorites),
        ),
        _ActionTile(
          icon: Icons.queue_music_rounded,
          title: 'Playlists',
          subtitle: '${stats.playlistCount} '
              '${stats.playlistCount == 1 ? 'playlist' : 'playlists'}',
          onTap: () => ShellNavigatorScope.of(context)?.goTo(ShellDestination.playlists),
        ),
        _ActionTile(
          icon: Icons.settings_rounded,
          title: 'Settings',
          subtitle: 'Appearance, audio, data',
          onTap: () => ShellNavigatorScope.of(context)?.goTo(ShellDestination.settings),
        ),
        const SizedBox(height: AppDimensions.lg),
        OutlinedButton.icon(
          onPressed: () => VibeActions.confirmLogout(context),
          icon: const Icon(Icons.logout_rounded, size: 18),
          label: const Text('LOG OUT'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF8FA6),
            side: const BorderSide(color: Color(0x55FF6B8A)),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
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
          Icon(icon, size: 18, color: VibeColors.softPink),
          const SizedBox(height: AppDimensions.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppDimensions.md),
        borderRadius: AppDimensions.radiusTile,
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: VibeColors.secondaryGradient,
              ),
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: VibeColors.mutedText),
          ],
        ),
      ),
    );
  }
}
