import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/song.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../screens/favorites/favorites_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/library/library_screen.dart';
import '../../screens/player/now_playing_screen.dart';
import '../../screens/playlists/playlists_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/statistics/statistics_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/light_pillar_background.dart';
import '../../widgets/mini_player.dart';
import '../../widgets/vibe_actions.dart';
import '../routes.dart';

/// Sections reachable from the shell navigation.
enum ShellDestination {
  home('Home'),
  search('Search'),
  library('Library'),
  favorites('Favourites'),
  playlists('Playlists'),
  statistics('Statistics'),
  settings('Settings'),
  profile('Profile');

  const ShellDestination(this.label);

  final String label;

  IconData get icon => switch (this) {
        ShellDestination.home => Icons.home_rounded,
        ShellDestination.search => Icons.search_rounded,
        ShellDestination.library => Icons.library_music_rounded,
        ShellDestination.favorites => Icons.favorite_rounded,
        ShellDestination.playlists => Icons.queue_music_rounded,
        ShellDestination.statistics => Icons.insights_rounded,
        ShellDestination.settings => Icons.settings_rounded,
        ShellDestination.profile => Icons.person_rounded,
      };

  IconData get outlineIcon => switch (this) {
        ShellDestination.home => Icons.home_outlined,
        ShellDestination.search => Icons.search_rounded,
        ShellDestination.library => Icons.library_music_outlined,
        ShellDestination.favorites => Icons.favorite_border_rounded,
        ShellDestination.playlists => Icons.queue_music_outlined,
        ShellDestination.statistics => Icons.insights_outlined,
        ShellDestination.settings => Icons.settings_outlined,
        ShellDestination.profile => Icons.person_outline_rounded,
      };
}

/// Mobile bottom bar (spec §27).
const List<ShellDestination> _mobileDestinations = <ShellDestination>[
  ShellDestination.home,
  ShellDestination.search,
  ShellDestination.library,
  ShellDestination.profile,
];

/// Desktop sidebar (spec §27).
const List<ShellDestination> _desktopDestinations = <ShellDestination>[
  ShellDestination.home,
  ShellDestination.search,
  ShellDestination.library,
  ShellDestination.favorites,
  ShellDestination.playlists,
  ShellDestination.statistics,
  ShellDestination.settings,
];

/// Lets nested screens (Profile, song actions) jump to a shell destination
/// without each of them owning a copy of the shell's index.
class ShellNavigatorScope extends InheritedWidget {
  const ShellNavigatorScope({
    super.key,
    required this.goTo,
    required super.child,
  });

  final ValueChanged<ShellDestination> goTo;

  static ShellNavigatorScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNavigatorScope>();

  @override
  bool updateShouldNotify(ShellNavigatorScope oldWidget) => false;
}

/// Responsive shell: bottom navigation on phones, a sidebar on tablet/desktop,
/// with the persistent mini player above the navigation (spec §15, §27, §28).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellDestination _current = ShellDestination.home;
  String? _reportedAudioError;

  void _select(ShellDestination destination) {
    if (_current == destination) {
      return;
    }
    setState(() => _current = destination);
  }

  void _reportAudioErrors(String? message) {
    if (message == null || message == _reportedAudioError) {
      return;
    }
    _reportedAudioError = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        VibeActions.showSnack(context, message, isError: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final SettingsProvider settings = context.watch<SettingsProvider>();
    final PlayerProvider player = context.watch<PlayerProvider>();

    _reportAudioErrors(player.errorMessage);

    return LightPillarBackground(
      quality: settings.backgroundQuality,
      reduceMotion: settings.reduceMotion,
      child: ShellNavigatorScope(
        goTo: _select,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool desktop =
                    AppBreakpoints.isDesktop(constraints.maxWidth);
                return desktop
                    ? _buildDesktop(constraints.maxWidth)
                    : _buildMobile();
              },
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile
  // ---------------------------------------------------------------------------

  Widget _buildMobile() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = AppBreakpoints.isTabletLandscape(screenWidth);
    return Column(
      children: <Widget>[
        Expanded(child: _ContentArea(current: _current)),
        const _MiniPlayerHost(),
        _BottomNav(
          current: _current,
          onSelect: _select,
          isTablet: isTablet,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet / desktop
  // ---------------------------------------------------------------------------

  Widget _buildDesktop(double width) {
    final bool extended = width >= 1024;
    return Row(
      children: <Widget>[
        _SideNav(
          destinations: _desktopDestinations,
          current: _current,
          extended: extended,
          onSelect: _select,
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              Expanded(child: _ContentArea(current: _current)),
              const _MiniPlayerHost(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps all shell screens alive simultaneously so scroll position and search
/// text survive navigation. Uses IndexedStack for O(1) switching without
/// destroying or rebuilding the previous page.
class _ContentArea extends StatelessWidget {
  const _ContentArea({required this.current});

  final ShellDestination current;

  static final List<ShellDestination> _destinations = ShellDestination.values;

  @override
  Widget build(BuildContext context) {
    final int index = _destinations.indexOf(current);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.wideContent),
        child: Padding(
          padding: const EdgeInsets.only(top: AppDimensions.xs),
          child: IndexedStack(
            index: index,
            children: <Widget>[
              for (final ShellDestination dest in _destinations) _buildScreen(dest),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(ShellDestination dest) {
    return switch (dest) {
      ShellDestination.home => const HomeScreen(),
      ShellDestination.search => const SearchScreen(),
      ShellDestination.library => const LibraryScreen(),
      ShellDestination.favorites => const FavoritesScreen(),
      ShellDestination.playlists => const PlaylistsScreen(),
      ShellDestination.statistics => const StatisticsScreen(),
      ShellDestination.settings => const SettingsScreen(),
      ShellDestination.profile => const ProfileScreen(),
    };
  }
}

/// Hosts the persistent mini player.
class _MiniPlayerHost extends StatelessWidget {
  const _MiniPlayerHost();

  @override
  Widget build(BuildContext context) {
    final PlayerProvider player = context.watch<PlayerProvider>();
    final LibraryProvider library = context.watch<LibraryProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppBreakpoints.wideContent),
          child: MiniPlayer(
            player: player,
            isFavorite: library.isFavorite,
            onToggleFavorite: library.toggleFavorite,
            onOpen: () {
              Navigator.of(context).push(
                fadeRoute(
                  const NowPlayingScreen(),
                  name: AppRoutes.nowPlaying,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.current,
    required this.onSelect,
    this.isTablet = false,
  });

  final ShellDestination current;
  final ValueChanged<ShellDestination> onSelect;
  final bool isTablet;

  @override
  Widget build(BuildContext context) {
    final int index = _mobileDestinations.indexOf(current);
    final double horizontalPad = isTablet ? AppDimensions.lg : AppDimensions.md;
    final double bottomPad = isTablet ? AppDimensions.md : AppDimensions.sm;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPad,
        0,
        horizontalPad,
        bottomPad,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: BackdropFilterGlassBar(
          child: NavigationBar(
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (int value) =>
                onSelect(_mobileDestinations[value]),
            destinations: <Widget>[
              for (final ShellDestination destination in _mobileDestinations)
                NavigationDestination(
                  icon: Icon(destination.outlineIcon),
                  selectedIcon: Icon(destination.icon),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.destinations,
    required this.current,
    required this.extended,
    required this.onSelect,
  });

  final List<ShellDestination> destinations;
  final ShellDestination current;
  final bool extended;
  final ValueChanged<ShellDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    return SizedBox(
      width: extended ? AppDimensions.railWidth : AppDimensions.railWidthCompact,
      child: BackdropFilterGlassBar(
        edge: Border(right: BorderSide(color: VibeColors.glassBorder(1))),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.xl),
              child: _BrandMark(extended: extended),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
                children: <Widget>[
                  for (final ShellDestination destination in destinations)
                    _RailTile(
                      destination: destination,
                      selected: destination == current,
                      extended: extended,
                      onTap: () => onSelect(destination),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: _RailTile(
                destination: ShellDestination.profile,
                selected: current == ShellDestination.profile,
                extended: extended,
                onTap: () => onSelect(ShellDestination.profile),
                trailing: UserBadge(user: auth.user),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.trailing,
  });

  final ShellDestination destination;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color color =
        selected ? VibeColors.softPink : VibeColors.textSecondary(0.85);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.xs),
      child: Material(
        color: selected
            ? VibeColors.electricBlue.withValues(alpha: 0.26)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? AppDimensions.md : 0,
              vertical: AppDimensions.md,
            ),
            child: Row(
              mainAxisAlignment:
                  extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  selected ? destination.icon : destination.outlineIcon,
                  size: 21,
                  color: color,
                ),
                if (extended) ...<Widget>[
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? VibeColors.white : color,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: VibeColors.primaryGradient,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: VibeColors.neonPink.withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(
            Icons.multitrack_audio_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        if (extended) ...<Widget>[
          const SizedBox(width: AppDimensions.md),
          ShaderMask(
            shaderCallback: (Rect bounds) =>
                VibeColors.primaryGradient.createShader(bounds),
            child: Text(
              'VibeVault',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Compact avatar showing the signed-in user's initials.
class UserBadge extends StatelessWidget {
  const UserBadge({super.key, required this.user, this.size = 22});

  final User? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: VibeColors.secondaryGradient,
        border: Border.all(color: VibeColors.glassBorder(1.4)),
      ),
      child: Text(
        user?.initials ?? '?',
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: VibeColors.white,
        ),
      ),
    );
  }
}

/// Shared blurred glass strip used by the bottom nav and the sidebar.
class BackdropFilterGlassBar extends StatelessWidget {
  const BackdropFilterGlassBar({
    super.key,
    required this.child,
    this.edge = const Border(),
  });

  final Widget child;
  final Border edge;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VibeColors.deepBackground.withValues(alpha: 0.42),
            border: edge,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Convenience helper used by list screens: play [songs] starting at [song].
void playListFrom(BuildContext context, List<Song> songs, Song song) {
  if (songs.isEmpty) {
    VibeActions.showSnack(
      context,
      'There is nothing to play here yet.',
      isError: true,
    );
    return;
  }
  unawaited(context.read<PlayerProvider>().playFrom(songs, song));
}
