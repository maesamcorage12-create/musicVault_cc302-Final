import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../repositories/playback_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/light_pillar_background.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Chooses between the login and register screens with a cross-fade (spec §6).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  int _index = 0;

  void _goTo(int index) {
    if (_index == index) {
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final BackgroundQuality quality =
        context.select<SettingsProvider, BackgroundQuality>(
      (SettingsProvider settings) => settings.backgroundQuality,
    );
    final bool reduceMotion =
        context.select<SettingsProvider, bool>(
      (SettingsProvider settings) => settings.reduceMotion,
    );

    return Scaffold(
      backgroundColor: VibeColors.deepBackground,
      resizeToAvoidBottomInset: true,
      body: LightPillarBackground(
        quality: quality,
        reduceMotion: reduceMotion,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= AppBreakpoints.desktop;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? AppDimensions.huge : AppDimensions.xl,
                  vertical: AppDimensions.xl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _AuthBrand(),
                        const SizedBox(height: AppDimensions.xl),
                        GlassCard(
                          intensity: GlassIntensity.strong,
                          padding: const EdgeInsets.all(AppDimensions.xl),
                          child: AnimatedSwitcher(
                            duration: AppDimensions.medium,
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: (
                              Widget child,
                              Animation<double> animation,
                            ) =>
                                FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0.05, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            ),
                            child: _index == 0
                                ? LoginScreen(
                                    key: const ValueKey<String>('login'),
                                    onRegisterRequested: () => _goTo(1),
                                  )
                                : RegisterScreen(
                                    key: const ValueKey<String>('register'),
                                    onLoginRequested: () => _goTo(0),
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.xl),
                        Text(
                          'VibeVault · local demo build',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      children: <Widget>[
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: VibeColors.primaryGradient,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: VibeColors.electricBlue.withValues(alpha: 0.42),
                blurRadius: 34,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VibeColors.deepBackground.withValues(alpha: 0.6),
              ),
              child: const Icon(
                Icons.multitrack_audio_rounded,
                size: 26,
                color: VibeColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        ShaderMask(
          shaderCallback: (Rect bounds) =>
              VibeColors.primaryGradient.createShader(bounds),
          child: Text(
            'VibeVault',
            style: text.displayMedium?.copyWith(
              color: Colors.white,
              letterSpacing: 1.4,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.xs),
        Text('Your music. Your vibe. Your vault.', style: text.bodyMedium),
      ],
    );
  }
}
