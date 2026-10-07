import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'artwork.dart';

/// Three bars that bounce while a track is playing (spec §32 "artwork animation
/// while playing"). Renders as a static glyph when paused.
class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({
    super.key,
    required this.isPlaying,
    this.size = 18,
    this.color = VibeColors.neonPink,
  });

  final bool isPlaying;
  final double size;
  final Color color;

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return CustomPaint(
            painter: _BarsPainter(
              phase: _controller.value,
              color: widget.color,
              active: widget.isPlaying,
            ),
          );
        },
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.phase, required this.color, required this.active});

  final double phase;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = active ? color : color.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final double barWidth = size.width * 0.22;
    final double gap = size.width * 0.10;
    final double total = barWidth * 3 + gap * 2;
    double x = (size.width - total) / 2;

    for (int i = 0; i < 3; i++) {
      final double offset = (phase + i * 0.22) % 1;
      final double wave = active
          ? (0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * offset * math.pi)))
          : 0.42 + 0.12 * i;
      final double height = size.height * wave.clamp(0.18, 1.0);
      final Rect rect = Rect.fromLTWH(
        x,
        (size.height - height) / 2,
        barWidth,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth)),
        paint,
      );
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.active != active ||
      oldDelegate.color != color;
}

/// The primary row used by every list of songs (Home, Search, Library,
/// Playlist detail, History).
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.isPlaying = false,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.trailingLabel,
    this.actions = const <Widget>[],
    this.showArtwork = true,
    this.showPlayingIndicator = true,
    this.subtitleOverride,
    this.dense = false,
  });

  final Song song;
  final VoidCallback? onTap;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Optional right-aligned secondary text (play count, added date, ...).
  final String? trailingLabel;
  final List<Widget> actions;
  final bool showArtwork;
  final bool showPlayingIndicator;
  final String? subtitleOverride;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= AppBreakpoints.desktop;
    final String subtitle = subtitleOverride ?? '${song.artist} • ${song.album}';

    return Material(
      color: isPlaying
          ? VibeColors.electricBlue.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusTile),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.horizontalPaddingFor(screenWidth),
            vertical: dense ? AppDimensions.sm : AppDimensions.md,
          ),
          child: Row(
            children: <Widget>[
              if (showArtwork) ...<Widget>[
                Artwork(
                  seed: song.id,
                  song: song,
                  size: dense
                      ? (isDesktop ? 42 : 38)
                      : (isDesktop
                          ? AppDimensions.tileArtworkDesktop
                          : AppDimensions.tileArtworkMobile),
                ),
                SizedBox(
                  width: isDesktop ? AppDimensions.md : AppDimensions.sm,
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (showPlayingIndicator && isPlaying) ...<Widget>[
                          PlayingIndicator(
                            isPlaying: true,
                            size: isDesktop ? 16 : 14,
                          ),
                          SizedBox(
                            width: isDesktop ? AppDimensions.sm : 4,
                          ),
                        ],
                        Expanded(
                          child: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              color: isPlaying
                                  ? VibeColors.softPink
                                  : VibeColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: isDesktop ? 1 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null) ...<Widget>[
                SizedBox(
                  width: isDesktop ? AppDimensions.sm : AppDimensions.xs,
                ),
                Text(trailingLabel!, style: text.bodySmall),
              ],
              SizedBox(
                width: isDesktop ? AppDimensions.sm : AppDimensions.xs,
              ),
              if (onToggleFavorite != null)
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
                    size: isDesktop ? 20 : 18,
                    color: isFavorite
                        ? VibeColors.neonPink
                        : VibeColors.textSecondary(0.85),
                  ),
                ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
