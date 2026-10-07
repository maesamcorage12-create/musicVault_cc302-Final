import 'package:flutter/material.dart' hide RepeatMode;

import '../models/playback_state.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Seek bar with elapsed / remaining labels (spec §16).
///
/// It keeps its own drag value so scrubbing is smooth and does not fight the
/// 10 Hz position stream coming from the player.
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    required this.player,
    this.showLabels = true,
    this.onSeekPreview,
  });

  final PlayerProvider player;
  final bool showLabels;
  final ValueChanged<Duration>? onSeekPreview;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final PlayerProvider player = widget.player;
    final Duration total = player.totalDuration;
    final bool hasDuration = total > Duration.zero;

    return ValueListenableBuilder<Duration>(
      valueListenable: player.position,
      builder: (BuildContext context, Duration live, Widget? _) {
        final double liveFraction = hasDuration
            ? (live.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;
        final double fraction = _dragValue ?? liveFraction;
        final Duration shown = _dragValue != null
            ? Duration(milliseconds: (fraction * total.inMilliseconds).round())
            : live;

        return Column(
          children: <Widget>[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: VibeColors.neonPink,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              ),
              child: Slider(
                value: fraction,
                onChanged: hasDuration
                    ? (double value) {
                        setState(() => _dragValue = value);
                        widget.onSeekPreview?.call(
                          Duration(
                            milliseconds: (value * total.inMilliseconds).round(),
                          ),
                        );
                      }
                    : null,
                onChangeEnd: hasDuration
                    ? (double value) {
                        setState(() => _dragValue = null);
                        player.seekTo(
                          Duration(milliseconds: (value * total.inMilliseconds).round()),
                        );
                      }
                    : null,
              ),
            ),
            if (widget.showLabels)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      Song.formatDuration(shown),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      hasDuration ? '-${Song.formatDuration(total - shown)}' : '--:--',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Circular transport button used by the full player (spec §16).
class TransportButton extends StatelessWidget {
  const TransportButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.filled = false,
    this.busy = false,
    this.tooltip,
    this.gradient,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final bool busy;
  final String? tooltip;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final Widget content = busy
        ? SizedBox(
            width: size * 0.42,
            height: size * 0.42,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: VibeColors.white,
            ),
          )
        : Icon(
            icon,
            size: size * 0.46,
            color: filled ? Colors.white : VibeColors.white,
          );

    final Widget button = Material(
      shape: CircleBorder(
        side: filled
            ? BorderSide.none
            : BorderSide(color: VibeColors.glassBorder(1.6)),
      ),
      clipBehavior: Clip.antiAlias,
      color: filled ? null : Colors.white.withValues(alpha: 0.06),
      elevation: filled ? 8 : 0,
      shadowColor: VibeColors.neonPink.withValues(alpha: 0.45),
      child: Ink(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled ? (gradient ?? VibeColors.primaryGradient) : null,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Shuffle / repeat toggles plus the favourite, queue and volume affordances
/// (spec §16).
class PlayerModeBar extends StatelessWidget {
  const PlayerModeBar({
    super.key,
    required this.player,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.onShowQueue,
    this.onShowVolume,
    this.showQueueButton = true,
  });

  final PlayerProvider player;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onShowQueue;
  final VoidCallback? onShowVolume;
  final bool showQueueButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _ModeToggle(
          icon: Icons.shuffle_rounded,
          label: 'Shuffle',
          active: player.shuffle,
          onPressed: player.toggleShuffle,
        ),
        _ModeToggle(
          icon: _repeatIcon(player.repeatMode),
          label: player.repeatMode.shortLabel,
          active: player.repeatMode != RepeatMode.off,
          onPressed: player.cycleRepeatMode,
        ),
        _ModeToggle(
          icon: isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          label: isFavorite ? 'Liked' : 'Like',
          active: isFavorite,
          activeColor: VibeColors.neonPink,
          onPressed: onToggleFavorite,
        ),
        if (showQueueButton && onShowQueue != null)
          _ModeToggle(
            icon: Icons.queue_music_rounded,
            label: 'Queue',
            active: false,
            onPressed: onShowQueue ?? () {},
          ),
        if (onShowVolume != null)
          _ModeToggle(
            icon: player.volume <= 0.01
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            label: '${(player.volume * 100).round()}%',
            active: false,
            onPressed: onShowVolume ?? () {},
          ),
      ],
    );
  }

  static IconData _repeatIcon(RepeatMode mode) => switch (mode) {
        RepeatMode.off => Icons.repeat_rounded,
        RepeatMode.all => Icons.repeat_on_rounded,
        RepeatMode.one => Icons.repeat_one_rounded,
      };
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.activeColor,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? (activeColor ?? VibeColors.softPink)
        : VibeColors.textSecondary(0.8);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedScale(
                  scale: active ? 1.06 : 1,
                  duration: AppDimensions.fast,
                  child: Icon(icon, size: 21, color: color),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
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

/// Volume slider used inside the queue/volume sheet (spec §16).
class VolumeControl extends StatelessWidget {
  const VolumeControl({super.key, required this.player, this.padding});

  final PlayerProvider player;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.sm),
      child: Row(
        children: <Widget>[
          const Icon(Icons.volume_down_rounded, size: 18, color: VibeColors.mutedText),
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: player.position,
              builder: (BuildContext context, Duration _, Widget? child) {
                // Rebuilds are not needed for volume; this listener only exists
                // so the slider repaints with the provider's volume changes.
                return child!;
              },
              child: Slider(
                value: player.volume,
                onChanged: player.setVolume,
              ),
            ),
          ),
          const Icon(Icons.volume_up_rounded, size: 18, color: VibeColors.mutedText),
        ],
      ),
    );
  }
}

/// The transport row: shuffle • previous • play/pause • next • repeat.
class TransportBar extends StatelessWidget {
  const TransportBar({super.key, required this.player, this.compact = false});

  final PlayerProvider player;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double playSize = compact ? 56 : 68;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        TransportButton(
          icon: Icons.skip_previous_rounded,
          onPressed: player.hasPrevious ? player.previous : null,
          size: compact ? 46 : 54,
          tooltip: 'Previous track',
        ),
        SizedBox(width: compact ? AppDimensions.md : AppDimensions.lg),
        TransportButton(
          icon: player.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onPressed: player.togglePlayPause,
          busy: player.isBusy,
          size: playSize,
          filled: true,
          tooltip: player.isPlaying ? 'Pause' : 'Play',
        ),
        SizedBox(width: compact ? AppDimensions.md : AppDimensions.lg),
        TransportButton(
          icon: Icons.skip_next_rounded,
          onPressed: player.hasNext ? player.next : null,
          size: compact ? 46 : 54,
          tooltip: 'Next track',
        ),
      ],
    );
  }
}

/// Compact header used by the queue sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(bottom: AppDimensions.lg),
        decoration: BoxDecoration(
          color: VibeColors.glassHighlight(1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Title + close row shared by the bottom sheets.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle, this.onClose});

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
      ],
    );
  }
}

/// Inline glass panel used inside sheets and dialogs.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.child, this.maxHeight});

  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final Widget panel = Padding(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: child,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(child: panel),
    );
  }
}

/// Gradient progress bar used in the now-playing header.
class GradientProgressBar extends StatelessWidget {
  const GradientProgressBar({super.key, required this.progress, this.height = 4});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: <Widget>[
          Container(height: height, color: Colors.white.withValues(alpha: 0.10)),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: const BoxDecoration(gradient: VibeColors.primaryGradient),
            ),
          ),
        ],
      ),
    );
  }
}
