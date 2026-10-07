import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';

/// Builds the single Material 3 dark theme used by every screen.
abstract final class AppTheme {
  static const String fontFamily = 'Roboto';

  static ColorScheme get _colorScheme => const ColorScheme(
        brightness: Brightness.dark,
        primary: VibeColors.neonPink,
        onPrimary: VibeColors.deepBackground,
        primaryContainer: VibeColors.electricBlue,
        onPrimaryContainer: VibeColors.white,
        secondary: VibeColors.brightBlue,
        onSecondary: VibeColors.deepBackground,
        secondaryContainer: VibeColors.electricBlue,
        onSecondaryContainer: VibeColors.white,
        tertiary: VibeColors.softPink,
        onTertiary: VibeColors.deepBackground,
        error: Color(0xFFFF6B8A),
        onError: VibeColors.deepBackground,
        surface: VibeColors.secondaryBackground,
        onSurface: VibeColors.white,
        onSurfaceVariant: VibeColors.mutedText,
        outline: Color(0xFF2A3352),
        outlineVariant: Color(0xFF1B2340),
      );

  static TextTheme get _textTheme {
    const Color primary = VibeColors.white;
    const Color secondary = VibeColors.mutedText;
    return const TextTheme(
      displayLarge: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        color: primary,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: primary,
        height: 1.15,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: primary,
        height: 1.2,
      ),
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: primary,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: primary,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.3,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
        height: 1.3,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: primary, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13.5, color: secondary, height: 1.45),
      bodySmall: TextStyle(fontSize: 12, color: secondary, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: primary,
      ),
      labelMedium: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: secondary,
      ),
      labelSmall: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: secondary,
      ),
    );
  }

  static ThemeData get dark {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: _colorScheme,
      scaffoldBackgroundColor: VibeColors.deepBackground,
      canvasColor: VibeColors.deepBackground,
      textTheme: _textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: _textTheme.apply(
        bodyColor: VibeColors.white,
        displayColor: VibeColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: VibeColors.white,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: VibeColors.white,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: VibeColors.glassBorder(1),
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: VibeColors.white, size: 22),
      cardTheme: CardThemeData(
        color: VibeColors.glassStrongFill(1),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: VibeColors.glassBorder(1)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: VibeColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: BorderSide(color: VibeColors.glassBorder(1.4)),
        ),
        titleTextStyle: _textTheme.headlineSmall,
        contentTextStyle: _textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: VibeColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: VibeColors.secondaryBackground,
        contentTextStyle: _textTheme.bodyMedium?.copyWith(
          color: VibeColors.white,
        ),
        actionTextColor: VibeColors.softPink,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(color: VibeColors.glassBorder(1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: VibeColors.glassFill(1.2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.lg,
          vertical: AppDimensions.lg,
        ),
        hintStyle: _textTheme.bodyMedium,
        labelStyle: _textTheme.bodyMedium,
        floatingLabelStyle: _textTheme.labelMedium?.copyWith(
          color: VibeColors.softPink,
        ),
        prefixIconColor: VibeColors.mutedText,
        suffixIconColor: VibeColors.mutedText,
        errorStyle: _textTheme.bodySmall?.copyWith(
          color: const Color(0xFFFF6B8A),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: BorderSide(color: VibeColors.glassBorder(1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: const BorderSide(
            color: VibeColors.neonPink,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          borderSide: const BorderSide(color: Color(0xFFFF6B8A), width: 1.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VibeColors.softPink,
          textStyle: _textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VibeColors.electricBlue,
          foregroundColor: VibeColors.white,
          disabledBackgroundColor: VibeColors.glassStrongFill(1),
          disabledForegroundColor: VibeColors.textSecondary(0.7),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
          textStyle: _textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: VibeColors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.xl),
          textStyle: _textTheme.labelLarge,
          side: BorderSide(color: VibeColors.glassBorder(1.6)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: VibeColors.white),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: VibeColors.glassFill(1),
        selectedColor: VibeColors.electricBlue,
        side: BorderSide(color: VibeColors.glassBorder(1)),
        labelStyle: _textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: VibeColors.electricBlue.withValues(alpha: 0.32),
        height: AppDimensions.bottomNavHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return _textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? VibeColors.white
                : VibeColors.mutedText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? VibeColors.white
                : VibeColors.mutedText,
          );
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: VibeColors.neonPink,
        linearTrackColor: Color(0xFF1B2340),
        circularTrackColor: Color(0xFF1B2340),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: VibeColors.neonPink,
        inactiveTrackColor: VibeColors.glassStrongFill(1),
        thumbColor: VibeColors.white,
        overlayColor: VibeColors.neonPink.withValues(alpha: 0.16),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: VibeColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppDimensions.sm),
          border: Border.all(color: VibeColors.glassBorder(1)),
        ),
        textStyle: _textTheme.bodySmall?.copyWith(color: VibeColors.white),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: VibeColors.mutedText,
        titleTextStyle: _textTheme.titleMedium,
        subtitleTextStyle: _textTheme.bodySmall,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: VibeColors.white,
        unselectedLabelColor: VibeColors.mutedText,
        indicatorColor: VibeColors.neonPink,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: _textTheme.titleSmall,
        unselectedLabelStyle: _textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
