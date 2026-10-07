import 'package:flutter/material.dart';

import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'artwork.dart';
import 'glass_card.dart';
import 'song_tile.dart';

/// Persistent mini player that sits above the bottom navigation (spec §15).
///
/// It stays mounted for the whole session so playback is never interrupted, and
/// it slides in/out as the queue becomes empty or non-empty.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    super.key,
    required this.player,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.isFavorite,
    this.margin = const EdgeInsets.only(left: AppDimensions.md, right: AppDimensions.md),
  });

  final PlayerProvider player;
  final VoidCallback onOpen;
  final bool Function(int songId) isFavorite;
  final void Function(int songId) onToggleFavorite;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final Song? song = player.currentSong;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= AppBreakpoints.desktop;
    final EdgeInsets margin = EdgeInsets.only(
      left: AppDimensions.miniPlayerMarginFor(screenWidth),
      right: AppDimensions.miniPlayerMarginFor(screenWidth),
    );

    return AnimatedSlide(
      offset: song == null ? const Offset(0, 1.4) : Offset.zero,
      duration: AppDimensions.medium,
      curve: AppDimensions.curve,
      child: AnimatedOpacity(
        opacity: song == null ? 0 : 1,
        duration: AppDimensions.medium,
        child: IgnorePointer(
          ignoring: song == null,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              margin.left,
              0,
              margin.right,
              margin.top,
            ),
            child: song == null
                ? const SizedBox(height: AppDimensions.miniPlayerHeight)
                : _MiniPlayerBody(
                    song: song,
                    player: player,
                    onOpen: onOpen,
                    isFavorite: isFavorite(song.id),
                    onToggleFavorite: () => onToggleFavorite(song.id),
                    isDesktop: isDesktop,
                  ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerBody extends StatelessWidget {
  const _MiniPlayerBody({
    required this.song,
    required this.player,
    required this.onOpen,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.isDesktop,
  });

  final Song song;
  final PlayerProvider player;
  final VoidCallback onOpen;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GlassCard(
          onTap: onOpen,
          intensity: GlassIntensity.strong,
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppDimensions.md : AppDimensions.sm,
            vertical: isDesktop ? AppDimensions.sm : AppDimensions.xs,
          ),
          borderRadius: AppDimensions.radiusButton,
          borderColor: VibeColors.glassHighlight(1),
          glowColor: VibeColors.neonPink,
          semanticLabel: 'Now playing ${song.title}. Tap to open the full player.',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Artwork(
                    seed: song.id,
                    song: song,
                    size: isDesktop ? 42 : 38,
                    showGlyph: false,
                  ),
                  SizedBox(
                    width: isDesktop ? AppDimensions.md : AppDimensions.sm,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            if (player.isPlaying) ...<Widget>[
                              PlayingIndicator(
                                isPlaying: true,
                                size: isDesktop ? 14 : 12,
                              ),
                              SizedBox(
                                width: isDesktop ? 6 : 4,
                              ),
                            ],
                            Expanded(
                              child: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall?.copyWith(
                                  color: player.isPlaying
                                      ? VibeColors.softPink
                                      : VibeColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop)
                    IconButton(
                      onPressed: onToggleFavorite,
                      visualDensity: VisualDensity.compact,
                      tooltip: isFavorite
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: isFavorite
                            ? VibeColors.neonPink
                            : VibeColors.textSecondary(0.85),
                      ),
                    ),
                  _MiniButton(
                    icon: player.isBusy
                        ? null
                        : (player.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                    loading: player.isBusy,
                    onPressed: player.togglePlayPause,
                    tooltip: player.isPlaying ? 'Pause' : 'Play',
                  ),
                  if (isDesktop)
                    _MiniButton(
                      icon: Icons.skip_next_rounded,
                      onPressed: player.hasNext ? player.next : null,
                      tooltip: 'Next track',
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppDimensions.sm),
                child: ValueListenableBuilder<Duration>(
                  valueListenable: player.position,
                  builder: (BuildContext context, Duration value, Widget? _) {
                    return _ProgressLine(progress: player.progress);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.loading = false,
  });

  final IconData? icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: loading ? null : onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 24,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VibeColors.softPink,
              ),
            )
          : Icon(icon, color: VibeColors.white),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 2.5,
        backgroundColor: Colors.white.withValues(alpha: 0.10),
        valueColor: const AlwaysStoppedAnimation<Color>(VibeColors.neonPink),
      ),
    );
  }
}
