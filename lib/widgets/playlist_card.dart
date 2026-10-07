import 'package:flutter/material.dart';

import '../models/playlist.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'artwork.dart';
import 'glass_card.dart';

/// Playlist card used on Home ("Made For You", "Your Playlists").
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.songCount,
    this.width = AppDimensions.playlistCardWidth,
    this.onTap,
    this.onPlay,
    this.trailing,
  });

  final Playlist playlist;
  final int songCount;
  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GlassCard(
            onTap: onTap,
            padding: EdgeInsets.all(width * 0.05),
            semanticLabel: 'Playlist ${playlist.name}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AspectRatio(
                  aspectRatio: 1,
                  child: Artwork(
                    seed: playlist.artworkSeed,
                    size: width,
                    label: monogram(playlist.name),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  playlist.description.isEmpty
                      ? '$songCount ${songCount == 1 ? 'song' : 'songs'}'
                      : playlist.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                if (onPlay != null) ...<Widget>[
                  const SizedBox(height: AppDimensions.md),
                  Row(
                    children: <Widget>[
                      _MiniAction(
                        icon: Icons.play_arrow_rounded,
                        label: 'Play',
                        onPressed: onPlay!,
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      _MiniAction(
                        icon: Icons.shuffle_rounded,
                        label: 'Shuffle',
                        onPressed: onPlay!,
                        outlined: true,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(top: AppDimensions.sm),
              child: trailing,
            ),
        ],
      ),
    );
  }

  /// "Night Vibes" -> "NV", "Focus" -> "F".
  static String monogram(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: outlined
            ? Colors.white.withValues(alpha: 0.08)
            : VibeColors.electricBlue.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.xs,
              vertical: AppDimensions.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 16, color: VibeColors.white),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: VibeColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Intrinsic height of a [PlaylistCard], used to size the horizontal shelves so
/// the cover, title, subtitle and the play/shuffle row always fit.
///
/// Derived from the card's own layout: cover (width - 2 x padding) + title +
/// subtitle + gaps + the play/shuffle row + the card padding.
double playlistCardHeight(double width) =>
    width * 0.9 + 16 + 20 + 2 + 17 + 16 + 32 + (width * 0.1) + 8;

/// Horizontal row variant of a playlist, used by the "Your Playlists" list on
/// Home, the Library playlists tab and the Playlists screen.
class PlaylistRowTile extends StatelessWidget {
  const PlaylistRowTile({
    super.key,
    required this.playlist,
    this.onTap,
    this.onPlay,
    this.onMore,
    this.subtitleOverride,
  });

  final Playlist playlist;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onMore;
  final String? subtitleOverride;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int count = playlist.songCount;
    final String subtitle = subtitleOverride ??
        (count == 0
            ? 'Empty playlist'
            : '$count ${count == 1 ? 'song' : 'songs'}');

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusTile,
      child: Row(
        children: <Widget>[
          Artwork(
            seed: playlist.artworkSeed,
            size: 56,
            label: PlaylistCard.monogram(playlist.name),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  playlist.description.isEmpty
                      ? subtitle
                       : '${playlist.description} · $subtitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (onPlay != null)
            IconButton(
              onPressed: onPlay,
              tooltip: 'Play playlist',
              icon: const Icon(Icons.play_circle_fill_rounded),
              iconSize: 30,
              color: VibeColors.softPink,
            ),
          if (onMore != null)
            IconButton(
              onPressed: onMore,
              tooltip: 'Playlist options',
              iconSize: 20,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
        ],
      ),
    );
  }
}
