import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Centered spinner for operations that block a whole screen (spec §31).
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message, this.padding});

  final String? message;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppDimensions.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: VibeColors.neonPink,
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: AppDimensions.lg),
              Text(message!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton placeholder used while lists load, so the screen never "suddenly
/// appears empty" (spec §31).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 64,
    this.width,
    this.borderRadius = AppDimensions.radiusTile,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(color: VibeColors.glassBorder(1)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                VibeColors.glassFill(0.6),
                VibeColors.glassStrongFill(1.4),
                VibeColors.glassFill(0.6),
              ],
              stops: <double>[
                0.1,
                0.5 + (_controller.value - 0.5) * 0.4,
                0.9,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A row of skeletons shaped like a song tile.
class SkeletonSongTile extends StatelessWidget {
  const SkeletonSongTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Row(
        children: <Widget>[
          const SkeletonBox(
            height: AppDimensions.tileArtwork,
            width: AppDimensions.tileArtwork,
            borderRadius: AppDimensions.radiusTile,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                SkeletonBox(height: 13, width: 170),
                SizedBox(height: AppDimensions.sm),
                SkeletonBox(height: 11, width: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder block for the whole section while loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < itemCount; i++) const SkeletonSongTile(),
      ],
    );
  }
}

/// Small inline spinner used inside buttons and cards.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.size = 18, this.strokeWidth = 2.2});

  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: VibeColors.softPink,
      ),
    );
  }
}
