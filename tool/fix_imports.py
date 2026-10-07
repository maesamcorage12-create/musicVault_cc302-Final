"""Rebuilds the import block for every Dart file under lib/.

Used once after an editing accident stripped every import; kept in the repo so
the import set can be regenerated/verified deterministically. Run with:

    python tool/fix_imports.py

The script maps each public symbol to the file that declares it, scans the file
body (comments excluded) for those symbols, and rewrites the import block in
dart:/package:/relative order. Afterwards `flutter analyze` reports any
`unused_import` warnings, which can be fed back in with --drop.
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

# symbol -> import path (relative to lib/)
SYMBOLS: dict[str, str] = {
    # theme
    "VibeColors": "theme/app_colors.dart",
    "AppDimensions": "theme/app_dimensions.dart",
    "AppBreakpoints": "theme/app_dimensions.dart",
    "AppTheme": "theme/app_theme.dart",
    # models
    "Song": "models/song.dart",
    "User": "models/user.dart",
    "Playlist": "models/playlist.dart",
    "HistoryEntry": "models/listening_history.dart",
    "ListeningStatistics": "models/statistics.dart",
    "RepeatMode": "models/playback_state.dart",
    "PlaybackState": "models/playback_state.dart",
    # data
    "SongCatalog": "data/song_catalog.dart",
    "PlaylistSeed": "data/song_catalog.dart",
    # services
    "StorageService": "services/storage_service.dart",
    "StorageException": "services/storage_service.dart",
    "AudioService": "services/audio_service.dart",
    "LoadOutcome": "services/audio_service.dart",
    "LoadStarted": "services/audio_service.dart",
    "LoadMissingAsset": "services/audio_service.dart",
    "LoadFailed": "services/audio_service.dart",
    # repositories
    "AuthException": "repositories/auth_repository.dart",
    "AuthRepository": "repositories/auth_repository.dart",
    "PlaylistException": "repositories/playlist_repository.dart",
    "PlaylistRepository": "repositories/playlist_repository.dart",
    "HistoryRepository": "repositories/history_repository.dart",
    "FavoritesRepository": "repositories/favorites_repository.dart",
    "PlaybackRepository": "repositories/playback_repository.dart",
    "SettingsRepository": "repositories/playback_repository.dart",
    "AppSettings": "repositories/playback_repository.dart",
    "BackgroundQuality": "repositories/playback_repository.dart",
    # providers
    "AuthStatus": "providers/auth_provider.dart",
    "AuthProvider": "providers/auth_provider.dart",
    "LibraryProvider": "providers/library_provider.dart",
    "PlaybackStatus": "providers/player_provider.dart",
    "PlayerProvider": "providers/player_provider.dart",
    "PlaylistProvider": "providers/playlist_provider.dart",
    "SettingsProvider": "providers/settings_provider.dart",
    "StatisticsProvider": "providers/statistics_provider.dart",
    # app
    "fadeRoute": "app/routes.dart",
    "AppRoutes": "app/routes.dart",
    "VibeVaultApp": "app/app.dart",
    "ShellDestination": "app/shell/app_shell.dart",
    "ShellNavigatorScope": "app/shell/app_shell.dart",
    "AppShell": "app/shell/app_shell.dart",
    "UserBadge": "app/shell/app_shell.dart",
    "BackdropFilterGlassBar": "app/shell/app_shell.dart",
    "playListFrom": "app/shell/app_shell.dart",
    # widgets
    "GlassCard": "widgets/glass_card.dart",
    "GradientGlassCard": "widgets/glass_card.dart",
    "SectionHeader": "widgets/glass_card.dart",
    "PageHeader": "widgets/page_header.dart",
    "Artwork": "widgets/artwork.dart",
    "Avatar": "widgets/artwork.dart",
    "GradientArt": "widgets/artwork.dart",
    "AlbumCard": "widgets/album_card.dart",
    "AlbumTile": "widgets/album_card.dart",
    "PlaylistCard": "widgets/playlist_card.dart",
    "PlaylistRowTile": "widgets/playlist_card.dart",
    "SongTile": "widgets/song_tile.dart",
    "PlayingIndicator": "widgets/song_tile.dart",
    "SearchSongList": "widgets/search_song_list.dart",
    "GroupDetailScreen": "widgets/group_detail_screen.dart",
    "GroupTrackList": "widgets/group_detail_screen.dart",
    "GroupDetailScope": "widgets/group_detail_screen.dart",
    "PlayHelper": "widgets/group_detail_screen.dart",
    "MiniPlayer": "widgets/mini_player.dart",
    "SeekBar": "widgets/player_controls.dart",
    "TransportButton": "widgets/player_controls.dart",
    "PlayerModeBar": "widgets/player_controls.dart",
    "TransportBar": "widgets/player_controls.dart",
    "VolumeControl": "widgets/player_controls.dart",
    "SheetHandle": "widgets/player_controls.dart",
    "SheetHeader": "widgets/player_controls.dart",
    "SheetBody": "widgets/player_controls.dart",
    "GradientProgressBar": "widgets/player_controls.dart",
    "EmptyState": "widgets/empty_state.dart",
    "ErrorView": "widgets/empty_state.dart",
    "LoadingView": "widgets/loading_view.dart",
    "SkeletonBox": "widgets/loading_view.dart",
    "SkeletonSongTile": "widgets/loading_view.dart",
    "SkeletonList": "widgets/loading_view.dart",
    "InlineSpinner": "widgets/loading_view.dart",
    "LightPillarBackground": "widgets/light_pillar_background.dart",
    "LightPillarPainter": "widgets/light_pillar_background.dart",
    "GlassScaffold": "widgets/glass_scaffold.dart",
    "VibeActions": "widgets/vibe_actions.dart",
    "GlassSheetFrame": "widgets/vibe_actions.dart",
    "AudioErrorBanner": "widgets/vibe_actions.dart",
    "greetingFor": "widgets/vibe_actions.dart",
    "songsForAlbum": "widgets/vibe_actions.dart",
    "songsForArtist": "widgets/vibe_actions.dart",
    "AuthTextField": "widgets/auth_form_parts.dart",
    "InlineError": "widgets/auth_form_parts.dart",
    "AuthButtonSpinner": "widgets/auth_form_parts.dart",
    "PasswordStrengthBar": "widgets/auth_form_parts.dart",
    # screens
    "SplashScreen": "screens/splash/splash_screen.dart",
    "AuthGate": "screens/auth/auth_gate.dart",
    "LoginScreen": "screens/auth/login_screen.dart",
    "RegisterScreen": "screens/auth/register_screen.dart",
    "HomeScreen": "screens/home/home_screen.dart",
    "SearchFilter": "screens/search/search_screen.dart",
    "SearchScreen": "screens/search/search_screen.dart",
    "LibraryScreen": "screens/library/library_screen.dart",
    "FavoritesScreen": "screens/favorites/favorites_screen.dart",
    "PlaylistsScreen": "screens/playlists/playlists_screen.dart",
    "PlaylistDetailScreen": "screens/playlists/playlist_detail_screen.dart",
    "NowPlayingScreen": "screens/player/now_playing_screen.dart",
    "ProfileScreen": "screens/profile/profile_screen.dart",
    "ListeningHistoryScreen": "screens/profile/listening_history_screen.dart",
    "StatisticsScreen": "screens/statistics/statistics_screen.dart",
    "SettingsScreen": "screens/settings/settings_screen.dart",
    "AlbumDetailScreen": "screens/album/album_detail_screen.dart",
    "ArtistDetailScreen": "screens/artist/artist_detail_screen.dart",
}

# symbol -> third-party package
PACKAGE_SYMBOLS: dict[str, str] = {
    "SharedPreferences": "package:shared_preferences/shared_preferences.dart",
    "AudioPlayer": "package:audioplayers/audioplayers.dart",
    "PlayerState": "package:audioplayers/audioplayers.dart",
    "PlayerMode": "package:audioplayers/audioplayers.dart",
    "ReleaseMode": "package:audioplayers/audioplayers.dart",
    "AssetSource": "package:audioplayers/audioplayers.dart",
    "Source": "package:audioplayers/audioplayers.dart",
    "sha256": "package:crypto/crypto.dart",
    "Consumer": "package:provider/provider.dart",
    "MultiProvider": "package:provider/provider.dart",
    "ChangeNotifierProvider": "package:provider/provider.dart",
    "ChangeNotifierProxyProvider": "package:provider/provider.dart",
    "ChangeNotifierProxyProvider2": "package:provider/provider.dart",
    "ChangeNotifierProxyProvider3": "package:provider/provider.dart",
    "Provider": "package:provider/provider.dart",
    "ProxyProvider": "package:provider/provider.dart",
    "SingleChildWidget": "package:provider/single_child_widget.dart",
    "ChangeNotifier": "package:flutter/foundation.dart",
    "ValueNotifier": "package:flutter/foundation.dart",
    "rootBundle": "package:flutter/services.dart",
    "SystemChrome": "package:flutter/services.dart",
    "SystemUiOverlayStyle": "package:flutter/services.dart",
}

DART_CORE: list[tuple[str, str]] = [
    ("dart:convert", r"\b(utf8|base64|base64Url|jsonEncode|jsonDecode)\b"),
    ("dart:math", r"(\bRandom\b|\bmath\.)"),
    ("dart:ui", r"\bImageFilter\b"),
]

# Files that must hide a Material name because the project declares its own.
# Keyed by lib-relative path; values map import URI -> trailing clause.
MODIFIERS: dict[str, dict[str, str]] = {
    "widgets/player_controls.dart": {
        "package:flutter/material.dart": " hide RepeatMode",
    },
    "screens/settings/settings_screen.dart": {
        "package:flutter/material.dart": " hide RepeatMode",
    },
}


def strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    # Blank out string literals so words like 'My Playlist' do not look like a
    # reference to the Playlist class.
    text = re.sub(r"'''.*?'''", '""', text, flags=re.S)
    text = re.sub(r'"""(.*?)"""', '""', text, flags=re.S)
    text = re.sub(r"'(\\.|[^'\\\n])*'", '""', text)
    text = re.sub(r'"(\\.|[^"\\\n])*"', '""', text)
    return text


def rel_prefix(from_file: str) -> str:
    rel = os.path.relpath(LIB, os.path.dirname(from_file))
    return "" if rel == "." else rel + os.sep


def rel_import(file_path: str, target: str) -> str:
    """Relative URI from `file_path` to a lib-relative `target`."""
    rel = os.path.relpath(os.path.join(LIB, target), os.path.dirname(file_path))
    return rel.replace(os.sep, "/")


def build_imports(file_path: str, body: str) -> list[str]:
    self_path = os.path.relpath(file_path, LIB).replace(os.sep, "/")
    found: set[str] = set()

    for symbol, target in SYMBOLS.items():
        if re.search(rf"\b{re.escape(symbol)}\b", body):
            abs_target = os.path.normpath(os.path.join(LIB, target))
            if abs_target != os.path.normpath(file_path):
                found.add(rel_import(file_path, target))
    for symbol, pkg in PACKAGE_SYMBOLS.items():
        if re.search(rf"\b{re.escape(symbol)}\b", body):
            found.add(pkg)

    if re.search(r"\b(Future|Stream|Timer|Completer|scheduleMicrotask|unawaited|"
                 r"StreamSubscription|StreamController)\b", body):
        found.add("dart:async")
    for uri, pattern in DART_CORE:
        if re.search(pattern, body):
            found.add(uri)

    if re.search(r"\b(context\.(watch|read|select|dependOnInheritedWidget))\b", body) \
            or "provider/provider.dart" in found:
        found.add("package:provider/provider.dart")

    flutter_symbols = (
        "Widget|BuildContext|StatelessWidget|StatefulWidget|State|Color|Colors|"
        "EdgeInsets|EdgeInsetsGeometry|Alignment|BoxDecoration|BoxShadow|"
        "BorderRadius|Radius|BoxConstraints|TextStyle|TextTheme|Theme|ThemeData|"
        "Icon|Icons|IconData|IconTheme|IconThemeData|SizedBox|Padding|Center|"
        "Column|Row|Stack|Positioned|ListView|GridView|SingleChildScrollView|"
        "Expanded|Flexible|Wrap|Spacer|Container|DecoratedBox|ClipRRect|ClipRect|"
        "Material|Ink|InkWell|Opacity|Transform|SizedBox|FutureBuilder|"
        "ValueListenableBuilder|ValueListenable|AnimatedBuilder|AnimatedSwitcher|"
        "FadeTransition|SlideTransition|ScaleTransition|AnimatedSlide|AnimatedOpacity|"
        "CurvedAnimation|CurvedAnimation|TickerProviderStateMixin|"
        "AnimationController|Animation|Tween|Bezier|Curves|SingleTickerProviderStateMixin|"
        "Scaffold|ScaffoldState|AppBar|SliverAppBar|TabBar|TabBarView|TabController|"
        "DefaultTabController|Text|TextField|TextFormField|InputDecoration|"
        "InputDecorationTheme|TextStyle|TextAlign|TextOverflow|TextCapitalization|"
        "TextInputType|TextInputAction|AutofillHints|Form|GlobalKey|"
        "NavigationBar|NavigationDestination|BottomNavigationBar|"
        "ScrollController|ScrollPhysics|BouncingScrollPhysics|"
        "Slider|LinearProgressIndicator|CircularProgressIndicator|"
        "IconButton|FilledButton|OutlinedButton|TextButton|IconButton|"
        "ChoiceChip|Chip|Switch|SwitchListTile|ListTile|Divider|"
        "showDialog|showModalBottomSheet|AlertDialog|Dialog|"
        "Navigator|Route|PageRouteBuilder|RouteSettings|MaterialPageRoute|"
        "FocusScope|FocusNode|TextEditingController|"
        "Semantics|MediaQuery|Directionality|SafeArea|"
        "TweenAnimationBuilder|AnimatedContainer|AnimatedOpacity|AnimatedScale|"
        "BackdropFilter|ImageFilter|ColorFilter|CustomPaint|CustomPainter|"
        "Canvas|Paint|MaskFilter|Gradient|LinearGradient|RadialGradient|SweepGradient|"
        "Offset|Size|Rect|RRect|RRect|Path|Color|shouldRepaint|"
        "CircularNotchedRectangle|"
        "WidgetStateProperty|WidgetState|MaterialStateProperty|"
        "PageTransitionsTheme|PageTransitionsBuilder|FadeForwardsPageTransitionsBuilder|"
        "CupertinoPageTransitionsBuilder|VisualDensity|"
        "InkSparkle|SelectionArea|Table|RenderBox"
    )
    if re.search(rf"\b({flutter_symbols})\b", body):
        found.add("package:flutter/material.dart")
    if re.search(r"\bCupertinoPageTransitionsBuilder\b", body):
        found.add("package:flutter/cupertino.dart")

    dart_imports = sorted(i for i in found if i.startswith("dart:"))
    pkg_imports = sorted(i for i in found if i.startswith("package:"))
    rel_imports = sorted(
        i for i in found
        if not i.startswith("dart:") and not i.startswith("package:")
    )
    mods = MODIFIERS.get(
        os.path.relpath(file_path, LIB).replace(os.sep, "/"), {}
    )

    def render(uri: str) -> str:
        if uri == "dart:math" and re.search(r"\bmath\.", body):
            return "import 'dart:math' as math;"
        return f"import '{uri}'{mods.get(uri, '')};"

    ordered: list[str] = []
    if dart_imports:
        ordered += [render(i) for i in dart_imports] + [""]
    if pkg_imports:
        ordered += [render(i) for i in pkg_imports] + [""]
    if rel_imports:
        ordered += [render(i) for i in rel_imports] + [""]
    return ordered


def strip_imports(text: str) -> str:
    text = re.sub(r"^import [^;]+;\s*$", "", text, flags=re.M)
    return text.lstrip("\n")


def process(path: str, drop: list[str]) -> bool:
    with open(path, "r", encoding="utf-8") as handle:
        original = handle.read()
    body_source = strip_imports(original)
    imports = build_imports(path, strip_comments(body_source))

    keep: list[str] = []
    for line in imports:
        target = line[len("import '"):-2]
        if any(target.endswith(d) for d in drop):
            continue
        keep.append(line)

    body = body_source.rstrip() + "\n"
    new_text = "\n".join(keep) + ("\n" if keep else "") + body
    if new_text == original:
        return False
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(new_text)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--drop", nargs="*", default=[],
                        help="import paths to omit (suffix match)")
    args = parser.parse_args()

    changed = 0
    for root, _dirs, files in os.walk(LIB):
        for name in sorted(files):
            if name.endswith(".dart"):
                if process(os.path.join(root, name), args.drop):
                    changed += 1
    print(f"rewrote imports in {changed} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())