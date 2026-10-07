import 'package:flutter/material.dart';

/// Named routes (spec §35).
///
/// The root route is `/`; the app swaps between the splash screen and the
/// shell with animated route replacement rather than rebuilding from scratch.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String shell = '/shell';

  static const String nowPlaying = '/now-playing';
  static const String playlist = '/playlist';
  static const String listeningHistory = '/listening-history';
  static const String album = '/album';
  static const String artist = '/artist';
  static const String search = '/search';
  static const String playlists = '/playlists';
  static const String settings = '/settings';
}

/// Fade + slight upward slide. Used for every push and for the root route swap
/// so the app feels like one continuous surface (spec §32).
Route<T> fadeRoute<T>(Widget page, {String? name}) {
  return PageRouteBuilder<T>(
    settings: RouteSettings(name: name),
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (BuildContext context, Animation<double> a, Animation<double> b) =>
        page,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<double> curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
