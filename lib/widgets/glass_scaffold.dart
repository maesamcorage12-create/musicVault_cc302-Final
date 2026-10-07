import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Scaffold used by pages that are pushed *on top of* the shell.
///
/// The shell already paints the animated LightPillar background, so a pushed
/// page only needs a mostly-opaque scrim plus safe-area handling. Keeping that in
/// one widget is what stops every pushed screen from reinventing it.
class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    super.key,
    required this.child,
    this.scrimOpacity = 0.90,
    this.bottomBar,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final double scrimOpacity;
  final Widget? bottomBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ColoredBox(
              color: VibeColors.deepBackground.withValues(alpha: scrimOpacity),
            ),
          ),
          Positioned.fill(child: SafeArea(child: child)),
          if (bottomBar != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: bottomBar!),
            ),
        ],
      ),
    );
  }
}
