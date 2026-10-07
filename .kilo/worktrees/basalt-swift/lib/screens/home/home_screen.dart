import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../app/shell/app_shell.dart';
import '../../data/song_catalog.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/album_card.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_scaffold.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_header.dart';
import '../../widgets/playlist_card.dart';
import '../../widgets/song_tile.dart';
import '../../widgets/vibe_actions.dart';
import '../playlists/playlist_detail_screen.dart';
import '../search/search_screen.dart';

/// Home (spec §17). Order: header, greeting, search, Recently Played,
/// Trending Now, Made For You, Your Playlists.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final LibraryProvider library = context.watch<LibraryProvider>();
    final PlaylistProvider playlists = context.watch<PlaylistProvider>();
    final StatisticsProvider stats = context.watch<StatisticsProvider>();

    final List<Song> recent = library.recentlyPlayed(limit: 10);
    final List<Song> trending = _trending(stats);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.xl,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        PageHeader(
          title: 'VibeVault',
          subtitle: _subtitle(auth.user?.username),
          trailing: const _QuickStats(),
        ),
        const _HomeSearchBar(),
        const SizedBox(height: AppDimensions.xl),

        // Recently played -------------------------------------------------
        SectionHeader(
          title: 'Recently Played',
          subtitle: recent.isEmpty
              ? 'Tracks you play will show up here'
              : 'Pick up where you left off',
        ),
        if (library.isLoading)
          const _RecentSkeleton()
        else if (recent.isEmpty)
          _RecentEmptyState(onBrowse: () => _goToSearch(context))
        else
          SizedBox(
            height: AppDimensions.albumCardSize + 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: recent.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.md),
              itemBuilder: (BuildContext context, int index) {
                final Song song = recent[index];
                return AlbumCard(
                  title: song.title,
                  subtitle: song.artist,
                  seed: song.id,
                  song: song,
                  onTap: () => playListFrom(context, recent, song),
                );
              },
            ),
          ),
        const SizedBox(height: AppDimensions.xl),

        // Trending now ----------------------------------------------------
        SectionHeader(
          title: 'Trending Now',
          subtitle: 'Most played across VibeVault right now',
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: AppDimensions.sm,
          ),
          child: Column(
            children: <Widget>[
              for (final Song song in trending)
                SongTile(
                  song: song,
                  dense: true,
                  isPlaying: context.watch<PlayerProvider>().currentSong?.id == song.id,
                  isFavorite: library.isFavorite(song.id),
                  onToggleFavorite: () => library.toggleFavorite(song.id),
                  onTap: () => playListFrom(context, trending, song),
                  trailingLabel: '${stats.playsFor(song.id)} plays',
                  actions: <Widget>[
                    IconButton(
                      onPressed: () =>
                          VibeActions.showSongActions(context, song, playContext: trending),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'More',
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.xl),

        // Made for you ----------------------------------------------------
        const SectionHeader(
          title: 'Made For You',
          subtitle: 'Curated mixes from the vault',
        ),
        if (playlists.isLoading)
          const _MixSkeleton()
        else if (playlists.playlists.isEmpty)
          _MixesEmptyState(
            onCreate: () =>
                VibeActions.showPlaylistEditor(context, suggestedName: 'My Mix'),
          )
        else
          SizedBox(
            height: playlistCardHeight(AppDimensions.playlistCardWidth),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: playlists.playlists.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.md),
              itemBuilder: (BuildContext context, int index) {
                final playlist = playlists.playlists[index];
                final List<Song> songs = playlists.songsFor(playlist);
                return PlaylistCard(
                  playlist: playlist,
                  songCount: playlist.songCount,
                  onPlay: () => _playPlaylist(context, songs, shuffle: false),
                  onTap: () => Navigator.of(context).push(
                    fadeRoute(
                      PlaylistDetailScreen(playlistId: playlist.id),
                      name: AppRoutes.playlist,
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: AppDimensions.xl),

        // Your playlists --------------------------------------------------
        SectionHeader(
          title: 'Your Playlists',
          subtitle: playlists.isEmpty
              ? 'Nothing here yet'
              : '${playlists.playlistCount} '
                  '${playlists.playlistCount == 1 ? 'playlist' : 'playlists'}',
          actionLabel: 'New playlist',
          onAction: () =>
              VibeActions.showPlaylistEditor(context, suggestedName: 'My Playlist'),
        ),
        if (playlists.isEmpty && !playlists.isLoading)
          _MixesEmptyState(
            onCreate: () => VibeActions.showPlaylistEditor(
              context,
              suggestedName: 'My Playlist',
            ),
          )
        else
          for (final playlist in playlists.playlists.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.md),
              child: PlaylistRowTile(
                playlist: playlist,
                onTap: () => Navigator.of(context).push(
                  fadeRoute(
                    PlaylistDetailScreen(playlistId: playlist.id),
                    name: AppRoutes.playlist,
                  ),
                ),
                onPlay: () => _playPlaylist(
                  context,
                  playlists.songsFor(playlist),
                  shuffle: false,
                ),
              ),
            ),
      ],
    );
  }

  // ---------------------------------------------------------------------------

  static void _playPlaylist(
    BuildContext context,
    List<Song> songs, {
    required bool shuffle,
  }) {
    if (songs.isEmpty) {
      VibeActions.showSnack(
        context,
        'Add songs to this playlist first.',
        isError: true,
      );
      return;
    }
    final PlayerProvider player = context.read<PlayerProvider>();
    if (shuffle && !player.shuffle) {
      player.toggleShuffle();
    }
    unawaited(player.playQueue(songs));
  }

  static void _goToSearch(BuildContext context) {
    Navigator.of(context).push(fadeRoute(const _SearchLauncher()));
  }

  /// Rule-based "trending": the listener's most-played tracks float to the top,
  /// everything else keeps catalog order. No hard-coded ranking (spec §17).
  static List<Song> _trending(StatisticsProvider stats) {
    final List<Song> songs = <Song>[...SongCatalog.all];
    songs.sort((Song a, Song b) {
      final int playsA = stats.playsFor(a.id);
      final int playsB = stats.playsFor(b.id);
      if (playsA == playsB) {
        return a.id.compareTo(b.id);
      }
      return playsB.compareTo(playsA);
    });
    return songs.take(6).toList(growable: false);
  }

  static String _subtitle(String? username) {
    if (username == null || username.isEmpty) {
      return 'Your music. Your vibe. Your vault.';
    }
    return '${greetingFor(DateTime.now())}, $username ✨';
  }
}

/// Small stat strip in the Home header.
class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    final StatisticsProvider stats = context.watch<StatisticsProvider>();
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: VibeColors.glassBorder(1)),
        gradient: LinearGradient(
          colors: <Color>[
            VibeColors.electricBlue.withValues(alpha: 0.22),
            VibeColors.neonPink.withValues(alpha: 0.16),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text('${stats.totalPlays}', style: text.titleMedium),
          Text('plays', style: text.labelSmall),
        ],
      ),
    );
  }
}

/// Search entry point on Home. Tapping pushes a dedicated search page so Home
/// stays a showcase and the keyboard does not fight the scroll view.
class _HomeSearchBar extends StatelessWidget {
  const _HomeSearchBar();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(fadeRoute(const _SearchLauncher())),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            color: VibeColors.glassFill(1.1),
            border: Border.all(color: VibeColors.glassBorder(1)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg,
            vertical: AppDimensions.lg,
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.search_rounded, size: 20, color: VibeColors.mutedText),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  'Search your vibe...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                  border: Border.all(color: VibeColors.glassBorder(1)),
                ),
                child: Text(
                  '30 tracks',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standalone search page reached from Home.
class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher();

  @override
  Widget build(BuildContext context) {
    return const GlassScaffold(child: SearchScreen(isStandalone: true));
  }
}

class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppDimensions.albumCardSize + 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.md),
        itemBuilder: (_, __) => const SizedBox(
          width: AppDimensions.albumCardSize,
          child: SkeletonBox(height: AppDimensions.albumCardSize),
        ),
      ),
    );
  }
}

class _MixSkeleton extends StatelessWidget {
  const _MixSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: playlistCardHeight(AppDimensions.playlistCardWidth),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.md),
        itemBuilder: (_, __) => SizedBox(
          width: AppDimensions.playlistCardWidth,
          child: SkeletonBox(
            height: playlistCardHeight(AppDimensions.playlistCardWidth),
          ),
        ),
      ),
    );
  }
}

class _RecentEmptyState extends StatelessWidget {
  const _RecentEmptyState({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onBrowse,
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: VibeColors.secondaryGradient,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: VibeColors.brightBlue.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Nothing played yet',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Play a track and your history appears here.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: VibeColors.mutedText),
        ],
      ),
    );
  }
}

class _MixesEmptyState extends StatelessWidget {
  const _MixesEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onCreate,
      child: Row(
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: VibeColors.primaryGradient,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: VibeColors.neonPink.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.queue_music_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Create your first playlist',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Group tracks into a mix and play it in one tap.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.add_rounded, color: VibeColors.mutedText),
        ],
      ),
    );
  }
}
