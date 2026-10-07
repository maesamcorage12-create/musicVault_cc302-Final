import 'package:flutter/material.dart';

/// Centralized VibeVault color system.
///
/// The whole application pulls its colors from here. Nothing else is allowed to
/// invent a hex value, which is what keeps the "70% dark / 20% glass / 10%
/// blue-pink accent" balance from drifting apart screen by screen.
abstract final class VibeColors {
  // Backgrounds -------------------------------------------------------------
  static const Color deepBackground = Color(0xFF070A18);
  static const Color secondaryBackground = Color(0xFF10162B);

  // Accents ----------------------------------------------------------------
  static const Color electricBlue = Color(0xFF5227FF);
  static const Color brightBlue = Color(0xFF4DA6FF);
  static const Color neonPink = Color(0xFFFF5DA2);
  static const Color softPink = Color(0xFFFF9FFC);

  // Foreground -------------------------------------------------------------
  static const Color white = Color(0xFFF8F7FF);
  static const Color mutedText = Color(0xFFA9AEC4);

  /// Gradients used across cards, buttons, dividers and the background painter.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[electricBlue, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: <Color>[brightBlue, softPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A soft rose used for the "pink glow" tail of the LightPillar background.
  static const LinearGradient glowGradient = LinearGradient(
    colors: <Color>[electricBlue, neonPink, softPink],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Glass surface tints. Kept as functions because they depend on opacity.
  static Color glassFill(double opacity) =>
      Colors.white.withValues(alpha: 0.06 * opacity);

  static Color glassStrongFill(double opacity) =>
      Colors.white.withValues(alpha: 0.10 * opacity);

  static Color glassBorder(double opacity) =>
      Colors.white.withValues(alpha: 0.10 * opacity);

  static Color glassHighlight(double opacity) =>
      Colors.white.withValues(alpha: 0.16 * opacity);

  /// Text colors that keep contrast readable on the dark canvas.
  static Color textPrimary([double opacity = 1]) =>
      white.withValues(alpha: opacity);

  static Color textSecondary([double opacity = 1]) =>
      mutedText.withValues(alpha: opacity);

  /// Deterministic accent pair derived from a seed (album/song artwork).
  static (Color, Color) accentPairFor(int seed) {
    const List<List<Color>> pairs = <List<Color>>[
      <Color>[electricBlue, neonPink],
      <Color>[brightBlue, softPink],
      <Color>[neonPink, electricBlue],
      <Color>[softPink, brightBlue],
      <Color>[electricBlue, brightBlue],
      <Color>[neonPink, softPink],
    ];
    return (pairs[seed.abs() % pairs.length][0], pairs[seed.abs() % pairs.length][1]);
  }
}
