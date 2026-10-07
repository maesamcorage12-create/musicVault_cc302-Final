import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

enum GlassIntensity {
  /// Cards sitting on the background with almost no fill.
  subtle,

  /// Default card treatment.
  regular,

  /// Sheets, dialogs and the now-playing surface.
  strong,
}

/// The glassmorphism surface used by every card, sheet and panel (spec §5).
///
/// Composition, top to bottom:
/// `BackdropFilter` blur → translucent white fill → 1px light border →
/// top-edge highlight → soft coloured shadow.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.lg),
    this.borderRadius = AppDimensions.radiusCard,
    this.intensity = GlassIntensity.regular,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.gradient,
    this.blurSigma,
    this.glowColor,
    this.margin,
    this.width,
    this.height,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final GlassIntensity intensity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final Gradient? gradient;
  final double? blurSigma;
  final Color? glowColor;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final String? semanticLabel;

  double get _blur => blurSigma ?? switch (intensity) {
        GlassIntensity.subtle => 14,
        GlassIntensity.regular => 20,
        GlassIntensity.strong => 28,
      };

  Color get _fill => switch (intensity) {
        GlassIntensity.subtle => VibeColors.glassFill(0.7),
        GlassIntensity.regular => VibeColors.glassFill(1.1),
        GlassIntensity.strong => VibeColors.glassStrongFill(1.3),
      };

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);
    final Widget surface = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gradient == null ? _fill : null,
            gradient: gradient,
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? VibeColors.glassBorder(1),
              width: 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              // Top-edge highlight: a 1px gradient that reads as a light source
              // above the card.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          VibeColors.glassHighlight(1.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // A transparent Material sits *between* the background and the
              // content so ListTile / InkWell / TextButton splashes paint on top
              // of the glass instead of being hidden behind it.
              Material(
                type: MaterialType.transparency,
                child: Padding(padding: padding, child: child),
              ),
            ],
          ),
        ),
      ),
    );

    final Widget shadowed = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: surface,
    );

    Widget result = shadowed;
    if (onTap != null || onLongPress != null) {
      result = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          splashColor: VibeColors.electricBlue.withValues(alpha: 0.18),
          highlightColor: VibeColors.neonPink.withValues(alpha: 0.10),
          child: shadowed,
        ),
      );
    }

    if (margin != null || width != null || height != null) {
      result = Padding(
        padding: margin ?? EdgeInsets.zero,
        child: SizedBox(width: width, height: height, child: result),
      );
    }

    return semanticLabel == null
        ? result
        : Semantics(label: semanticLabel, button: onTap != null, child: result);
  }
}

/// Convenience variant with the primary blue→pink gradient as its fill.
class GradientGlassCard extends StatelessWidget {
  const GradientGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.lg),
    this.borderRadius = AppDimensions.radiusCard,
    this.gradient = VibeColors.primaryGradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Gradient gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      borderRadius: borderRadius,
      gradient: gradient,
      borderColor: Colors.white.withValues(alpha: 0.18),
      onTap: onTap,
      child: child,
    );
  }
}

/// Section heading used across Home, Library, Search and Profile.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: text.titleLarge),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
