import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../widgets/artwork.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/glass_scaffold.dart';
import '../../widgets/player_controls.dart';
import '../../widgets/vibe_actions.dart';
import '../artist/artist_detail_screen.dart';

/// Full-screen player (spec §16).
///
/// ```text
/// artwork → title/artist → seek bar + times →
/// shuffle • previous • play/pause • next • repeat
/// ```
/// plus the favourite, queue and volume affordances.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PlayerProvider player = context.watch<PlayerProvider>();
    final LibraryProvider library = context.watch<LibraryProvider>();
    final Song? song = player.currentSong;

    if (song == null) {
      return GlassScaffold(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const Expanded(
              child: EmptyState(
                icon: Icons.album_outlined,
                title: 'Nothing is playing',
                message: 'Pick a track from Home, Search or your Library and it '
                    'will show up here.',
              ),
            ),
          ],
        ),
      );
    }

    return GlassScaffold(
      scrimOpacity: 0.86,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= AppBreakpoints.desktop;
          final double artSize = _artworkSize(constraints);

          final Widget header = _NowPlayingHeader(song: song, player: player);
          final Widget art = _Artwork(song: song, size: artSize);
          final Widget meta = _SongMeta(song: song, library: library);
          final Widget seek = SeekBar(player: player);
          final Widget transport = Column(
            children: <Widget>[
              TransportBar(player: player),
              const SizedBox(height: AppDimensions.lg),
              PlayerModeBar(
                player: player,
                isFavorite: library.isFavorite(song.id),
                onToggleFavorite: () => library.toggleFavorite(song.id),
                onShowQueue: () => VibeActions.showQueueSheet(context),
                onShowVolume: () => _showVolumeSheet(context, player),
              ),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.xl,
              AppDimensions.md,
              AppDimensions.xl,
              AppDimensions.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                header,
                const SizedBox(height: AppDimensions.lg),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      art,
                      const SizedBox(width: AppDimensions.huge),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            meta,
                            const SizedBox(height: AppDimensions.lg),
                            seek,
                            const SizedBox(height: AppDimensions.xl),
                            transport,
                          ],
                        ),
                      ),
                    ],
                  )
                else ...<Widget>[
                  Center(child: art),
                  const SizedBox(height: AppDimensions.xl),
                  meta,
                  const SizedBox(height: AppDimensions.lg),
                  seek,
                  const SizedBox(height: AppDimensions.xl),
                  transport,
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static double _artworkSize(BoxConstraints constraints) {
    if (constraints.maxWidth >= AppBreakpoints.desktop) {
      return (constraints.maxHeight * 0.52).clamp(180.0, 420.0);
    }
    return (constraints.maxWidth * 0.78).clamp(200.0, 340.0);
  }

  static Future<void> _showVolumeSheet(
    BuildContext context,
    PlayerProvider player,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: VibeColors.secondaryBackground.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: VibeColors.glassBorder(1.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SheetHandle(),
                  SheetHeader(
                    title: 'Volume',
                    subtitle: '${(player.volume * 100).round()}%',
                    onClose: () => Navigator.pop(sheetContext),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  VolumeControl(player: player),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NowPlayingHeader extends StatelessWidget {
  const _NowPlayingHeader({required this.song, required this.player});

  final Song song;
  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              Text(
                'NOW PLAYING',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 2.4,
                      color: VibeColors.softPink,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                player.queueLength > 1
                    ? '${player.queueIndex + 1} of ${player.queueLength}'
                    : song.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => VibeActions.showSongActions(
            context,
            song,
            playContext: player.queue,
          ),
          tooltip: 'More',
          icon: const Icon(Icons.more_vert_rounded),
        ),
      ],
    );
  }
}

/// Artwork with a slow breathing animation while playing (spec §32).
class _Artwork extends StatefulWidget {
  const _Artwork({required this.song, required this.size});

  final Song song;
  final double size;

  @override
  State<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<_Artwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final bool playing = context.read<PlayerProvider>().isPlaying;
    if (playing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!playing && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        <Listenable>[_pulse, context.watch<PlayerProvider>()],
      ),
      builder: (BuildContext context, _) {
        final bool playing = context.read<PlayerProvider>().isPlaying;
        final double scale = 1 + (playing ? _pulse.value * 0.018 : 0);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: VibeColors.neonPink.withValues(alpha: 0.24),
                  blurRadius: widget.size * 0.34,
                  offset: Offset(0, widget.size * 0.14),
                ),
                BoxShadow(
                  color: VibeColors.electricBlue.withValues(alpha: 0.26),
                  blurRadius: widget.size * 0.24,
                  offset: Offset(0, -widget.size * 0.06),
                ),
              ],
            ),
            child: Artwork(
              seed: widget.song.id,
              song: widget.song,
              size: widget.size,
              borderRadiusFactor: 0.14,
            ),
          ),
        );
      },
    );
  }
}

class _SongMeta extends StatelessWidget {
  const _SongMeta({required this.song, required this.library});

  final Song song;
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          song.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.headlineMedium,
        ),
        const SizedBox(height: AppDimensions.xs),
        GestureDetector(
          onTap: () => _openArtist(context),
          child: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(color: VibeColors.softPink),
          ),
        ),
        if (song.description != null && song.description!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppDimensions.md),
          Text(song.description!, style: text.bodySmall),
        ],
        const SizedBox(height: AppDimensions.md),
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: <Widget>[
            _Chip(label: song.genre),
            _Chip(label: song.album),
            if (song.year != null) _Chip(label: '${song.year}'),
            _Chip(label: library.isFavorite(song.id) ? 'Liked' : 'Not saved'),
          ],
        ),
      ],
    );
  }

  void _openArtist(BuildContext context) {
    unawaited(
      Navigator.of(context).push(
        fadeRoute(ArtistDetailScreen(artist: song.artist), name: AppRoutes.artist),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(color: VibeColors.glassBorder(1.2)),
        color: VibeColors.glassFill(1),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
