import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'artwork.dart';
import 'glass_card.dart';
import 'song_tile.dart';
import 'vibe_actions.dart';

/// Full-screen detail for one album, artist or playlist.
///
/// All three are the same shape — a hero header plus the tracks that belong to
/// the group — so they share this widget and pass a pre-filtered [songs] list.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({
    super.key,
    required this.title,
    required this.seed,
    required this.songs,
    this.description,
    this.subtitleOverride,
    this.headerTrailing,
    this.emptyLabel = 'Nothing here yet.',
  });

  final String title;
  final int seed;
  final List<Song> songs;
  final String? description;

  /// Replaces the generated "N tracks · mm:ss" line (playlists use this).
  final String? subtitleOverride;
  final Widget? headerTrailing;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Duration total = Duration(
      seconds: songs.fold<int>(
        0,
        (int sum, Song song) => sum + song.duration.inSeconds,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ColoredBox(
              color: VibeColors.deepBackground.withValues(alpha: 0.92),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: <Widget>[
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg,
                    0,
                    AppDimensions.lg,
                    AppDimensions.xxl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: GroupDetailScope(
                      songs: songs,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          GlassCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Artwork(seed: seed, size: 96, label: _monogram(title)),
                                const SizedBox(width: AppDimensions.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.titleLarge,
                                      ),
                                      if (description != null &&
                                          description!.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 4),
                                        Text(description!, style: text.bodySmall),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        subtitleOverride ??
                                            '${songs.length} '
                                                '${songs.length == 1 ? 'track' : 'tracks'} · '
                                                '${Song.formatDuration(total)}',
                                        style: text.bodySmall,
                                      ),
                                      const SizedBox(height: AppDimensions.md),
                                      Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: songs.isEmpty
                                                  ? null
                                                  : () => PlayHelper.play(context, songs),
                                              icon: const Icon(
                                                Icons.play_arrow_rounded,
                                                size: 18,
                                              ),
                                              label: const Text('PLAY'),
                                            ),
                                          ),
                                          const SizedBox(width: AppDimensions.sm),
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: songs.isEmpty
                                                  ? null
                                                  : () =>
                                                      PlayHelper.shuffle(context, songs),
                                              icon: const Icon(
                                                Icons.shuffle_rounded,
                                                size: 18,
                                              ),
                                              label: const Text('SHUFFLE'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (headerTrailing != null) headerTrailing!,
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.lg),
                          if (songs.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.xxl,
                              ),
                              child: Text(
                                emptyLabel,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium,
                              ),
                            )
                          else
                            const GroupTrackList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _monogram(String name) {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return null;
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Inherited scope that lets [GroupTrackList] reach the group's song list
/// without every caller threading it through the constructor.
class GroupDetailScope extends InheritedWidget {
  const GroupDetailScope({
    super.key,
    required this.songs,
    required super.child,
  });

  final List<Song> songs;

  static GroupDetailScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GroupDetailScope>();

  @override
  bool updateShouldNotify(GroupDetailScope oldWidget) =>
      !identical(oldWidget.songs, songs);
}

/// The track list body shared by album, artist and playlist detail screens.
class GroupTrackList extends StatelessWidget {
  const GroupTrackList({super.key, this.onRemove});

  /// When provided, each row gets a "remove from this group" action (used by
  /// playlist detail).
  final void Function(Song song)? onRemove;

  @override
  Widget build(BuildContext context) {
    final List<Song> songs = GroupDetailScope.of(context)?.songs ?? const <Song>[];
    final PlayerProvider player = context.watch<PlayerProvider>();
    final LibraryProvider library = context.watch<LibraryProvider>();

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
                    tooltip: 'Remove from group',
                    icon: const Icon(
                      Icons.remove_circle_outline_rounded,
                      color: VibeColors.mutedText,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Playback helpers kept out of the widgets so screens stay declarative.
abstract final class PlayHelper {
  static void play(BuildContext context, List<Song> songs, {Song? startAt}) {
    if (songs.isEmpty) {
      return;
    }
    if (startAt == null) {
      unawaited(context.read<PlayerProvider>().playQueue(songs));
    } else {
      unawaited(context.read<PlayerProvider>().playFrom(songs, startAt));
    }
  }

  static void shuffle(BuildContext context, List<Song> songs) {
    if (songs.isEmpty) {
      return;
    }
    final PlayerProvider player = context.read<PlayerProvider>();
    if (!player.shuffle) {
      player.toggleShuffle();
    }
    unawaited(player.playQueue(songs));
  }
}
