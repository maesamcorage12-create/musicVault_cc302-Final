import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/statistics_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/history_repository.dart';
import '../repositories/playback_repository.dart';
import '../repositories/playlist_repository.dart';
import '../screens/auth/auth_gate.dart';
import '../screens/splash/splash_screen.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_theme.dart';
import 'shell/app_shell.dart';

/// Root widget: builds the dependency graph and swaps between the splash
/// screen, the auth gate and the main shell as the session resolves
/// (spec §6 — Splash → Check Session → Home | Sign In).
class VibeVaultApp extends StatefulWidget {
  const VibeVaultApp({
    super.key,
    required this.storage,
    required this.initialSettings,
  });

  final StorageService storage;
  final AppSettings initialSettings;

  @override
  State<VibeVaultApp> createState() => _VibeVaultAppState();
}

class _VibeVaultAppState extends State<VibeVaultApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        // ---- Services & repositories --------------------------------------
        Provider<StorageService>.value(value: widget.storage),
        Provider<AuthRepository>(
          create: (BuildContext _) => AuthRepository(widget.storage),
        ),
        Provider<PlaylistRepository>(
          create: (BuildContext _) => PlaylistRepository(widget.storage),
        ),
        Provider<HistoryRepository>(
          create: (BuildContext _) => HistoryRepository(widget.storage),
        ),
        Provider<FavoritesRepository>(
          create: (BuildContext _) => FavoritesRepository(widget.storage),
        ),
        Provider<PlaybackRepository>(
          create: (BuildContext _) => PlaybackRepository(widget.storage),
        ),
        Provider<SettingsRepository>(
          create: (BuildContext _) => SettingsRepository(widget.storage),
        ),
        Provider<AudioService>(
          create: (BuildContext _) => AudioService(),
          dispose: (BuildContext _, AudioService service) {
            unawaited(service.dispose());
          },
        ),

        // ---- State --------------------------------------------------------
        ChangeNotifierProvider<SettingsProvider>(
          create: (BuildContext context) =>
              SettingsProvider(context.read<SettingsRepository>())
                ..applyInitial(widget.initialSettings),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (BuildContext context) =>
              AuthProvider(context.read<AuthRepository>()),
        ),

        // Library and playlists follow the signed-in account. `update` runs
        // during build, so both providers defer their own async work.
        ChangeNotifierProxyProvider<AuthProvider, LibraryProvider>(
          create: (BuildContext context) => LibraryProvider(
            context.read<FavoritesRepository>(),
            context.read<HistoryRepository>(),
          ),
          update: (_, AuthProvider auth, LibraryProvider? library) =>
              library!..syncUser(auth.user?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PlaylistProvider>(
          create: (BuildContext context) =>
              PlaylistProvider(context.read<PlaylistRepository>()),
          update: (_, AuthProvider auth, PlaylistProvider? playlists) =>
              playlists!..syncUser(auth.user?.id),
        ),

        // The player reports every play to the library, so the two are bound.
        ChangeNotifierProxyProvider2<AuthProvider, LibraryProvider,
            PlayerProvider>(
          create: (BuildContext context) => PlayerProvider(
            context.read<AudioService>(),
            context.read<PlaybackRepository>(),
          ),
          update: (
            _,
            AuthProvider auth,
            LibraryProvider library,
            PlayerProvider? player,
          ) =>
              player!
                ..bindUser(auth.user?.id)
                ..bindLibrary(library),
        ),

        // Statistics are derived state: references are enough.
        ChangeNotifierProxyProvider2<LibraryProvider, PlaylistProvider,
            StatisticsProvider>(
          create: (BuildContext _) => StatisticsProvider(),
          update: (
            _,
            LibraryProvider library,
            PlaylistProvider playlists,
            StatisticsProvider? statistics,
          ) =>
              statistics!..bind(library, playlists),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (BuildContext context, SettingsProvider settings, _) {
          return MaterialApp(
            title: 'VibeVault',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            themeMode: ThemeMode.dark,
            home: const _AppRouter(),
            builder: (BuildContext context, Widget? child) {
              // Clamp text scaling so the dense player UI cannot overflow.
              final MediaQueryData media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: media.textScaler.clamp(
                    minScaleFactor: 0.85,
                    maxScaleFactor: 1.3,
                  ),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Chooses between the splash screen, the auth gate and the shell.
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  /// Splash is held for at least this long even if the session check is fast,
  /// so the animation gets to play (spec §7: 1-2 seconds).
  static const Duration _minimumSplash = Duration(milliseconds: 1700);

  bool _splashElapsed = false;
  late final Timer _splashTimer;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<AuthProvider>().restoreSession());
    _splashTimer = Timer(_minimumSplash, () {
      if (mounted) {
        setState(() => _splashElapsed = true);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (BuildContext context, AuthProvider auth, _) {
        final bool showSplash =
            auth.status == AuthStatus.unknown || !_splashElapsed;
        final Widget screen = showSplash
            ? const SplashScreen()
            : (auth.isAuthenticated ? const AppShell() : const AuthGate());

        return AnimatedSwitcher(
          duration: AppDimensions.medium,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: ValueKey<String>(screen.runtimeType.toString()),
            child: screen,
          ),
        );
      },
    );
  }
}
