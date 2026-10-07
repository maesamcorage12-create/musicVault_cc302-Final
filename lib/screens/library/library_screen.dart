import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../data/song_catalog.dart';
import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/album_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glass_scaffold.dart';
import '../../widgets/group_detail_screen.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/page_header.dart';
import '../../widgets/playlist_card.dart';
import '../../widgets/search_song_list.dart';
import '../../widgets/vibe_actions.dart';
import '../album/album_detail_screen.dart';
import '../playlists/playlist_detail_screen.dart';
import '../search/search_screen.dart';

/// Library (spec §19): Playlists, Songs and Albums, plus a "liked songs"
/// shortcut that leads to the favourites screen.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryProvider library = context.watch<LibraryProvider>();
    final PlaylistProvider playlists = context.watch<PlaylistProvider>();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.xl,
            AppDimensions.lg,
            AppDimensions.md,
          ),
          child: PageHeader(
            title: 'Library',
            subtitle: '${playlists.playlistCount} '
                '${playlists.playlistCount == 1 ? 'playlist' : 'playlists'} · '
                '${library.favoriteCount} '
                '${library.favoriteCount == 1 ? 'liked song' : 'liked songs'}',
            trailing: IconButton(
              onPressed: () => VibeActions.showPlaylistEditor(
                context,
                suggestedName: 'My Playlist',
              ),
              tooltip: 'New playlist',
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ),
        TabBar(
          controller: _tabs,
          tabs: const <Widget>[
            Tab(text: 'Playlists'),
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: <Widget>[
              _PlaylistsTab(playlists: playlists),
              const _SongsTab(),
              const _AlbumsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab({required this.playlists});

  final PlaylistProvider playlists;

  @override
  Widget build(BuildContext context) {
    if (playlists.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.xl),
        child: SkeletonList(itemCount: 5),
      );
    }
    if (playlists.isEmpty) {
      return EmptyState(
        icon: Icons.queue_music_rounded,
        title: 'Your library is empty.',
        message: 'Create your first playlist and start building your vibe.',
        actionLabel: '+ CREATE PLAYLIST',
        onAction: () => VibeActions.showPlaylistEditor(
          context,
          suggestedName: 'My Playlist',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      itemCount: playlists.playlists.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (BuildContext context, int index) {
        final playlist = playlists.playlists[index];
        final List<Song> songs = playlists.songsFor(playlist);
        return PlaylistRowTile(
          playlist: playlist,
          onTap: () => Navigator.of(context).push(
            fadeRoute(
              PlaylistDetailScreen(playlistId: playlist.id),
              name: AppRoutes.playlist,
            ),
          ),
          onPlay: songs.isEmpty ? null : () => PlayHelper.play(context, songs),
          onMore: () => VibeActions.showPlaylistMenu(context, playlist),
        );
      },
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab();

  @override
  Widget build(BuildContext context) {
    final LibraryProvider library = context.watch<LibraryProvider>();
    final List<Song> songs = library.favoriteSongs;

    if (library.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.xl),
        child: SkeletonList(itemCount: 6),
      );
    }
    if (songs.isEmpty) {
      return EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No liked songs yet.',
        message:
            'Tap the heart on a song to save it here. Your picks survive '
            'closing the app.',
        actionLabel: 'BROWSE CATALOG',
        onAction: () => unawaited(
          Navigator.of(context).push(
            fadeRoute(
              const GlassScaffold(child: SearchScreen(isStandalone: true)),
              name: AppRoutes.search,
            ),
          ),
        ),
      );
    }

    final Duration total = Duration(
      seconds: songs.fold<int>(
        0,
        (int sum, Song song) => sum + song.duration.inSeconds,
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        GlassCard(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Liked Songs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${songs.length} '
                      '${songs.length == 1 ? 'track' : 'tracks'} · '
                      '${Song.formatDuration(total)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => PlayHelper.play(context, songs),
                tooltip: 'Play liked songs',
                icon: const Icon(Icons.play_arrow_rounded),
              ),
              const SizedBox(width: AppDimensions.sm),
              IconButton.filled(
                onPressed: () => PlayHelper.shuffle(context, songs),
                tooltip: 'Shuffle liked songs',
                icon: const Icon(Icons.shuffle_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.lg),
        SearchSongList(songs: songs),
      ],
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context) {
    final List<String> albums = SongCatalog.albums;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 112,
        crossAxisSpacing: AppDimensions.md,
        mainAxisSpacing: AppDimensions.md,
      ),
      itemCount: albums.length,
      itemBuilder: (BuildContext context, int index) {
        final String album = albums[index];
        final List<Song> songs = SongCatalog.all
            .where((Song s) => s.album == album)
            .toList(growable: false);
        final String artists =
            (songs.map((Song s) => s.artist).toSet().toList()..sort()).join(', ');
        return AlbumTile(
          album: album,
          seed: album.hashCode,
          trackCount: songs.length,
          artists: artists,
          artworkSong: songs.isNotEmpty ? songs.first : null,
          onTap: () => Navigator.of(context).push(
            fadeRoute(
              AlbumDetailScreen(album: album),
              name: AppRoutes.album,
            ),
          ),
        );
      },
    );
  }
}
