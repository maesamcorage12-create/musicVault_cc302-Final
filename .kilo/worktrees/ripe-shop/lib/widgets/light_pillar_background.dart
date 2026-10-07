import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../repositories/playback_repository.dart';
import '../theme/app_colors.dart';

/// Full-screen animated LightPillar environment (spec §4).
///
/// Layer order, painted by [LightPillarPainter]:
///
/// ```text
/// dark gradient wash
///      ↓
/// blue light pillars (MaskFilter blur)
///      ↓
/// purple transition + pink glow
///      ↓
/// drifting particles
///      ↓
/// vignette
/// ```
///
/// The whole thing sits behind an [IgnorePointer] so it can never intercept a
/// tap, and the render budget comes from [BackgroundQuality] so slow devices can
/// turn the cost down.
class LightPillarBackground extends StatefulWidget {
  const LightPillarBackground({
    super.key,
    required this.child,
    this.quality = BackgroundQuality.high,
    this.reduceMotion = false,
  });

  final Widget child;
  final BackgroundQuality quality;

  /// Accessibility switch: freezes the animation at a pleasant static pose
  /// instead of disabling the artwork entirely.
  final bool reduceMotion;

  @override
  State<LightPillarBackground> createState() => _LightPillarBackgroundState();
}

class _LightPillarBackgroundState extends State<LightPillarBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.quality.cycleDuration,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      _controller.repeat();
    } else {
      _controller.value = 0.18;
    }
  }

  @override
  void didUpdateWidget(LightPillarBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quality != widget.quality) {
      _controller.duration = widget.quality.cycleDuration;
      if (!widget.reduceMotion) {
        _controller.repeat();
      }
    }
    if (oldWidget.reduceMotion != widget.reduceMotion) {
      if (widget.reduceMotion) {
        _controller.stop();
        _controller.value = 0.18;
      } else {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // IgnorePointer guarantees the background never blocks interaction.
        IgnorePointer(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? _) {
                return CustomPaint(
                  painter: LightPillarPainter(
                    progress: _controller.value,
                    quality: widget.quality,
                  ),
                  isComplex: true,
                  willChange: _controller.isAnimating,
                );
              },
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Paints the LightPillar scene. Pure painting — no state, no I/O.
class LightPillarPainter extends CustomPainter {
  LightPillarPainter({
    required this.progress,
    this.quality = BackgroundQuality.high,
    this.intensity = 1,
  });

  /// Animation phase in the range `0..1`.
  final double progress;
  final BackgroundQuality quality;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress * 2 * math.pi;

    _paintBaseWash(canvas, size);
    _paintAmbientGlows(canvas, size, t);
    _paintPillars(canvas, size, t);
    _paintParticles(canvas, size, t);
    _paintVignette(canvas, size);
  }

  void _paintBaseWash(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xFF0B1026),
          VibeColors.deepBackground,
          Color(0xFF0A0E20),
        ],
        stops: <double>[0, 0.45, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintAmbientGlows(Canvas canvas, Size size, double t) {
    final double sigma = quality.blurSigma * 1.6;

    // Purple transition near the top.
    _paintGlow(
      canvas,
      Offset(
        size.width * (0.5 + 0.05 * math.sin(t * 0.7)),
        size.height * (0.16 + 0.012 * math.cos(t)),
      ),
      size.shortestSide * 0.78,
      VibeColors.electricBlue,
      0.30 * intensity,
      sigma,
    );

    // Pink glow toward the lower third.
    _paintGlow(
      canvas,
      Offset(
        size.width * (0.30 + 0.06 * math.sin(t * 0.5 + 1.3)),
        size.height * (0.78 + 0.02 * math.sin(t * 0.9)),
      ),
      size.shortestSide * 0.62,
      VibeColors.neonPink,
      0.20 * intensity,
      sigma,
    );

    // Cool blue counterweight on the right.
    _paintGlow(
      canvas,
      Offset(
        size.width * (0.82 + 0.04 * math.cos(t * 0.6)),
        size.height * (0.46 + 0.015 * math.sin(t * 1.1)),
      ),
      size.shortestSide * 0.5,
      VibeColors.brightBlue,
      0.14 * intensity,
      sigma,
    );
  }

  void _paintGlow(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
    double sigma,
  ) {
    final Paint paint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.35),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    canvas.drawCircle(center, radius, paint);
  }

  void _paintPillars(Canvas canvas, Size size, double t) {
    final int count = quality.pillarCount;
    final double sigma = quality.blurSigma;

    for (int i = 0; i < count; i++) {
      final double phase = t * (0.55 + i * 0.08) + i * 1.7;
      // Base positions spread across the canvas; pillars 0 and last are pinned
      // further out so the composition keeps a focal centre.
      final double base = 0.08 + (i / (count - 1).clamp(1, count)) * 0.84;
      final double drift = 0.018 * math.sin(phase) + 0.008 * math.sin(phase * 2.3);
      final double x = size.width * (base + drift).clamp(-0.05, 1.05);

      final double widthFactor = 0.045 + 0.022 * ((i * 37) % 5) / 5;
      final double width = (size.width * widthFactor)
          .clamp(18.0, size.width * 0.13);
      final double top = -size.height * 0.12;
      final double height = size.height * 1.24;

      // Pillar height breathes slightly so they read as light, not as bars.
      final double stretch = 1 + 0.03 * math.sin(phase * 0.8 + i);

      final double alpha =
          (0.16 + 0.10 * (0.5 + 0.5 * math.sin(phase * 0.6 + i * 0.9))) *
              intensity;

      final Paint paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            VibeColors.brightBlue.withValues(alpha: 0),
            VibeColors.electricBlue.withValues(alpha: alpha),
            VibeColors.neonPink.withValues(alpha: alpha * 0.82),
            VibeColors.softPink.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.28, 0.68, 1],
        ).createShader(
          Rect.fromLTWH(x - width / 2, top, width, height * stretch),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - width / 2, top, width, height * stretch),
          Radius.circular(width),
        ),
        paint,
      );

      // A crisp inner core keeps the pillar readable behind the glass UI.
      final Paint core = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            VibeColors.white.withValues(alpha: 0),
            VibeColors.white.withValues(alpha: 0.10 * intensity),
            VibeColors.white.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromLTWH(x - width * 0.18, top, width * 0.36, height * stretch),
        );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - width * 0.18, top, width * 0.36, height * stretch),
          Radius.circular(width * 0.2),
        ),
        core,
      );
    }
  }

  void _paintParticles(Canvas canvas, Size size, double t) {
    final int count = quality.particleCount;
    final Paint paint = Paint();
    for (int i = 0; i < count; i++) {
      // Deterministic pseudo-random layout so the field never flickers.
      final double fx = ((i * 0.6180339887) % 1);
      final double fy = ((i * 0.3819660113) % 1);
      final double driftPhase = t * (0.25 + (i % 5) * 0.06) + i;

      final double x = size.width * (fx + 0.02 * math.sin(driftPhase));
      final double y =
          size.height * (fy + 0.03 * math.cos(driftPhase * 0.8)) - size.height * 0.03;
      final double radius = 0.8 + (i % 4) * 0.55;
      final double alpha =
          (0.05 + 0.10 * (0.5 + 0.5 * math.sin(driftPhase * 1.7))) * intensity;

      paint.color = (i.isEven ? VibeColors.white : VibeColors.softPink)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _paintVignette(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: <Color>[
          Colors.transparent,
          VibeColors.deepBackground.withValues(alpha: 0.35),
          VibeColors.deepBackground.withValues(alpha: 0.82),
        ],
        stops: const <double>[0.45, 0.78, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant LightPillarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.quality != quality ||
      oldDelegate.intensity != intensity;
}
