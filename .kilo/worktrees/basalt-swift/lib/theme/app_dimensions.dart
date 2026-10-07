import 'package:flutter/material.dart';

/// Spacing, radius and sizing tokens.
///
/// All layout values come from here so that "20-24px cards, 14-18px buttons"
/// stays true across every screen.
abstract final class AppDimensions {
  // Spacing scale ----------------------------------------------------------
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 48;

  // Corner radii ------------------------------------------------------------
  static const double radiusCard = 22;
  static const double radiusButton = 16;
  static const double radiusChip = 14;
  static const double radiusTile = 16;

  // Component sizes --------------------------------------------------------
  static const double miniPlayerHeight = 64;
  static const double bottomNavHeight = 68;
  static const double railWidth = 248;
  static const double railWidthCompact = 84;
  static const double tileArtwork = 52;
  static const double searchBarHeight = 52;

  // Artwork ----------------------------------------------------------------
  static const double albumCardSize = 168;
  static const double playlistCardWidth = 208;

  // Motion -----------------------------------------------------------------
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve curveEmphasized = Curves.easeOutBack;
}

/// Responsive breakpoints (spec §28).
abstract final class AppBreakpoints {
  /// Below this width the shell uses a bottom navigation bar.
  static const double desktop = 700;

  /// At or above this width the content column is width-capped and centred.
  static const double wideContent = 1180;

  static bool isMobile(double width) => width < AppBreakpoints.desktop;
  static bool isDesktop(double width) => width >= AppBreakpoints.desktop;
}
