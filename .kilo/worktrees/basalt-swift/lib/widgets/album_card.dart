import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'artwork.dart';
import 'glass_card.dart';

/// Large cover card used by "Recently Played" and album rows on Home.
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.seed,
    this.song,
    this.size = AppDimensions.albumCardSize,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final int seed;
  final Song? song;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return SizedBox(
      width: size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GlassCard(
            onTap: onTap,
            padding: EdgeInsets.all(size * 0.06),
            borderRadius: AppDimensions.radiusCard,
            semanticLabel: '$title, $subtitle',
            child: AspectRatio(
              aspectRatio: 1,
              child: Artwork(seed: seed, song: song, size: size),
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Album (release) card: cover plus a fan of up to three tracks from it.
class AlbumTile extends StatelessWidget {
  const AlbumTile({
    super.key,
    required this.album,
    required this.seed,
    required this.trackCount,
    required this.artists,
    this.onTap,
  });

  final String album;
  final int seed;
  final int trackCount;
  final String artists;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusTile,
      child: Row(
        children: <Widget>[
          Artwork(seed: seed, size: 64),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  album,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  artists,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '$trackCount ${trackCount == 1 ? 'track' : 'tracks'}',
                  style: text.labelSmall?.copyWith(color: VibeColors.softPink),
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
