import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/song_catalog.dart';
import '../../models/song.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/album_card.dart';
import '../../widgets/artwork.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/search_song_list.dart';
import '../album/album_detail_screen.dart';
import '../artist/artist_detail_screen.dart';

enum SearchFilter {
  all('All'),
  songs('Songs'),
  artists('Artists'),
  albums('Albums');

  const SearchFilter(this.label);

  final String label;
}

/// Search (spec §18).
///
/// Plain in-memory filtering over 30 tracks: each song exposes a pre-lowercased
/// search haystack, so results update on every keystroke without extra work.
/// The Artists/Albums tabs group the same matches instead of re-scanning.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.isStandalone = false});

  /// True when pushed on top of the shell from Home (adds a back button).
  final bool isStandalone;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  String _query = '';
  SearchFilter _filter = SearchFilter.all;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    // A short debounce keeps typing smooth on low-end devices while still
    // feeling instant.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), () {
      if (mounted) {
        setState(() => _query = _controller.text.trim().toLowerCase());
      }
    });
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focusNode.unfocus();
  }

  List<String> get _terms =>
      _query.isEmpty ? const <String>[] : _query.split(RegExp(r'\s+'));

  List<Song> get _songs {
    if (_terms.isEmpty) {
      return SongCatalog.all;
    }
    return SongCatalog.all.where((Song song) {
      final String haystack = song.searchIndex;
      return _terms.every(haystack.contains);
    }).toList(growable: false);
  }

  List<String> _namesFrom(List<String> universe) {
    if (_terms.isEmpty) {
      return universe;
    }
    return universe
        .where((String name) {
          final String lower = name.toLowerCase();
          return _terms.every(lower.contains);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<Song> songs = _songs;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.lg,
            AppDimensions.sm,
          ),
          child: Row(
            children: <Widget>[
              if (widget.isStandalone) ...<Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppDimensions.sm),
              ],
              Expanded(
                child: _SearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onClear: _clear,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
            children: <Widget>[
              for (final SearchFilter filter in SearchFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppDimensions.sm),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.sm),
        Expanded(
          child: switch (_filter) {
            SearchFilter.all => _AllTab(
                songs: songs,
                hasQuery: _query.isNotEmpty,
                rawQuery: _controller.text.trim(),
                onClear: _clear,
              ),
            SearchFilter.songs => _SongsTab(
                songs: songs,
                hasQuery: _query.isNotEmpty,
                rawQuery: _controller.text.trim(),
                onClear: _clear,
              ),
            SearchFilter.artists => _NamesTab(
                names: _namesFrom(SongCatalog.artists),
                isArtist: true,
                hasQuery: _query.isNotEmpty,
                onClear: _clear,
              ),
            SearchFilter.albums => _NamesTab(
                names: _namesFrom(SongCatalog.albums),
                isArtist: false,
                hasQuery: _query.isNotEmpty,
                onClear: _clear,
              ),
          },
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: Theme.of(context).textTheme.bodyLarge,
      cursorColor: VibeColors.softPink,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search your vibe...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (BuildContext context, TextEditingValue value, _) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              onPressed: onClear,
              tooltip: 'Clear',
              iconSize: 18,
              icon: const Icon(Icons.close_rounded),
            );
          },
        ),
      ),
    );
  }
}

/// "All" tab: songs first, then the matching artists and albums.
class _AllTab extends StatelessWidget {
  const _AllTab({
    required this.songs,
    required this.hasQuery,
    required this.rawQuery,
    required this.onClear,
  });

  final List<Song> songs;
  final bool hasQuery;
  final String rawQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _NoResults(rawQuery: rawQuery, onClear: onClear);
    }

    final List<String> artists =
        (songs.map((Song s) => s.artist).toSet().toList())..sort();
    final List<String> albums =
        (songs.map((Song s) => s.album).toSet().toList())..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        0,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[
        SectionHeader(
          title: hasQuery ? 'Songs' : 'All songs',
          subtitle: '${songs.length} ${songs.length == 1 ? 'match' : 'matches'}',
        ),
        SearchSongList(songs: songs),
        if (artists.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppDimensions.xl),
          SectionHeader(title: 'Artists', subtitle: '${artists.length} found'),
          for (final String artist in artists)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: _NameRow(
                title: artist,
                subtitle: '${songs.where((Song s) => s.artist == artist).length} tracks',
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.of(context).push(
                  fadeRoute(
                    ArtistDetailScreen(artist: artist),
                    name: AppRoutes.artist,
                  ),
                ),
              ),
            ),
        ],
        if (albums.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppDimensions.xl),
          SectionHeader(title: 'Albums', subtitle: '${albums.length} found'),
          for (final String album in albums)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
              child: AlbumTile(
                album: album,
                seed: album.hashCode,
                trackCount: songs.where((Song s) => s.album == album).length,
                artworkSong: songs.firstWhere(
                  (Song s) => s.album == album,
                  orElse: () => songs.first,
                ),
                artists: (songs
                        .where((Song s) => s.album == album)
                        .map((Song s) => s.artist)
                        .toSet()
                        .toList()
                      ..sort())
                    .join(', '),
              ),
            ),
        ],
      ],
    );
  }
}

class _SongsTab extends StatelessWidget {
  const _SongsTab({
    required this.songs,
    required this.hasQuery,
    required this.rawQuery,
    required this.onClear,
  });

  final List<Song> songs;
  final bool hasQuery;
  final String rawQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) {
      return _NoResults(rawQuery: rawQuery, onClear: onClear);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        0,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      children: <Widget>[SearchSongList(songs: songs)],
    );
  }
}

class _NamesTab extends StatelessWidget {
  const _NamesTab({
    required this.names,
    required this.isArtist,
    required this.hasQuery,
    required this.onClear,
  });

  final List<String> names;
  final bool isArtist;
  final bool hasQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (names.isEmpty) {
      return EmptyState(
        icon: isArtist ? Icons.person_off_rounded : Icons.album_outlined,
        title: hasQuery
            ? 'No matching ${isArtist ? 'artists' : 'albums'}'
            : 'Nothing to show',
        message: hasQuery
            ? 'Try a different search term, or clear the search to see all of '
                'the catalog.'
            : 'The catalog has no ${isArtist ? 'artists' : 'albums'} yet.',
        actionLabel: 'Clear search',
        onAction: onClear,
        compact: true,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg,
        0,
        AppDimensions.lg,
        AppDimensions.xxl,
      ),
      itemCount: names.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (BuildContext context, int index) {
        final String name = names[index];
        final int count = SongCatalog.all
            .where((Song s) => isArtist ? s.artist == name : s.album == name)
            .length;
        return _NameRow(
          title: name,
          subtitle: '$count ${count == 1 ? 'track' : 'tracks'}',
          icon: isArtist ? Icons.person_outline_rounded : Icons.album_outlined,
          onTap: () => Navigator.of(context).push(
            fadeRoute(
              isArtist
                  ? ArtistDetailScreen(artist: name)
                  : AlbumDetailScreen(album: name),
              name: isArtist ? AppRoutes.artist : AppRoutes.album,
            ),
          ),
        );
      },
    );
  }
}

/// No-match state with a "show everything" escape hatch (spec §29/§37).
class _NoResults extends StatelessWidget {
  const _NoResults({required this.rawQuery, required this.onClear});

  final String rawQuery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.search_off_rounded,
      title: rawQuery.isEmpty ? 'No songs' : 'No results for "$rawQuery"',
      message:
          'Try a different title, artist, album or genre — the catalog has '
          '30 tracks to search.',
      actionLabel: 'Show all songs',
      onAction: onClear,
      compact: true,
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppDimensions.md),
      borderRadius: AppDimensions.radiusTile,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Artwork(
            seed: title.hashCode,
            size: 48,
            label: title.substring(0, 1).toUpperCase(),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(icon, size: 18, color: VibeColors.mutedText),
        ],
      ),
    );
  }
}
