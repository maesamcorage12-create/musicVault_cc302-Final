import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../repositories/playback_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/light_pillar_background.dart';

/// Animated splash (spec §7).
///
/// Shows the VibeVault mark with a fade + scale entrance, the tagline
/// "Your music. / Your vibe. / Your vault." and the LightPillar environment. The
/// router keeps this screen mounted for ~1.7s while it checks the stored
/// session, so the animation always gets to finish.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: AppDimensions.slow,
  )..forward();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _intro,
    curve: AppDimensions.curveEmphasized,
  );

  late final Animation<double> _logoOpacity = CurvedAnimation(
    parent: _intro,
    curve: Curves.easeOut,
  );

  late final Animation<double> _textOpacity = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );

  late final AnimationController _glowPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _intro.dispose();
    _glowPulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BackgroundQuality quality = context.select<SettingsProvider, BackgroundQuality>(
      (SettingsProvider settings) => settings.backgroundQuality,
    );
    final bool reduceMotion = context.select<SettingsProvider, bool>(
      (SettingsProvider settings) => settings.reduceMotion,
    );

    return Scaffold(
      backgroundColor: VibeColors.deepBackground,
      body: LightPillarBackground(
        quality: quality,
        reduceMotion: reduceMotion,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedBuilder(
                  animation: Listenable.merge(
                    <Listenable>[_logoScale, _glowPulse],
                  ),
                  builder: (BuildContext context, _) {
                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.82, end: 1).animate(_logoScale),
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: _GlowLogo(pulse: _glowPulse.value),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.xxl),
                FadeTransition(
                  opacity: _textOpacity,
                  child: const _VibeWordmark(),
                ),
                const SizedBox(height: AppDimensions.sm),
                FadeTransition(
                  opacity: _textOpacity,
                  child: Text(
                    'Your music.\nYour vibe.\nYour vault.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.7,
                          letterSpacing: 1.2,
                          color: VibeColors.textSecondary(0.95),
                        ),
                  ),
                ),
                const SizedBox(height: AppDimensions.huge),
                FadeTransition(
                  opacity: _textOpacity,
                  child: SizedBox(
                    width: 132,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Color(0xFF1B2340),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(VibeColors.neonPink),
                      ),
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

/// The animated vault glyph: a gradient disc with an equaliser cut into it.
class _GlowLogo extends StatelessWidget {
  const _GlowLogo({required this.pulse});

  final double pulse;

  @override
  Widget build(BuildContext context) {
    final double glow = 0.55 + 0.45 * math.sin(pulse * math.pi);
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: VibeColors.primaryGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: VibeColors.electricBlue.withValues(alpha: 0.35 * glow),
            blurRadius: 64 * glow,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: VibeColors.neonPink.withValues(alpha: 0.32 * glow),
            blurRadius: 40 * glow,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VibeColors.deepBackground.withValues(alpha: 0.62),
          ),
          child: const Icon(
            Icons.multitrack_audio_rounded,
            size: 46,
            color: VibeColors.white,
          ),
        ),
      ),
    );
  }
}

class _VibeWordmark extends StatelessWidget {
  const _VibeWordmark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) =>
          VibeColors.primaryGradient.createShader(bounds),
      child: Text(
        'VibeVault',
        style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 1.5,
            ),
      ),
    );
  }
}
