import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/routes.dart';
import '../data/song_catalog.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../providers/auth_provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/album/album_detail_screen.dart';
import '../screens/artist/artist_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'player_controls.dart';
import 'song_tile.dart';

/// Shared sheet/dialog helpers. Keeping them here means every screen reports
/// success and failure the same way (spec §30).
abstract final class VibeActions {
  /// Shows a themed SnackBar. Errors get the pink accent and an icon.
  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                size: 18,
                color: isError
                    ? const Color(0xFFFF8FA6)
                    : VibeColors.softPink,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(child: Text(message)),
            ],
          ),
          duration: Duration(milliseconds: isError ? 4200 : 2600),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }

  /// Create / rename playlist dialog. Returns `true` when something changed.
  static Future<bool> showPlaylistEditor(
    BuildContext context, {
    Playlist? playlist,
    List<int> seedSongIds = const <int>[],
    String? suggestedName,
  }) async {
    final TextEditingController name = TextEditingController(
      text: playlist?.name ?? suggestedName ?? '',
    );
    final TextEditingController description = TextEditingController(
      text: playlist?.description ?? '',
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _PlaylistEditorDialog(
          playlist: playlist,
          nameController: name,
          descriptionController: description,
        );
      },
    );

    if (result != true || !context.mounted) {
      return false;
    }

    final PlaylistProvider playlists = context.read<PlaylistProvider>();
    final bool ok;
    if (playlist == null) {
      ok = await playlists.create(
        name: name.text,
        description: description.text,
        songIds: seedSongIds,
      );
    } else {
      ok = await playlists.rename(
        playlistId: playlist.id,
        name: name.text,
        description: description.text,
      );
    }

    if (!context.mounted) {
      return ok;
    }
    if (ok) {
      showSnack(
        context,
        playlist == null
            ? (seedSongIds.isEmpty
                ? 'Playlist "${name.text.trim()}" created.'
                : 'Playlist created with ${seedSongIds.length} '
                    '${seedSongIds.length == 1 ? 'song' : 'songs'}.')
            : 'Playlist renamed.',
      );
    } else {
      showSnack(
        context,
        playlists.errorMessage ?? 'Could not save the playlist.',
        isError: true,
      );
    }
    return ok;
  }

  /// Delete confirmation. Respects `confirmBeforeDeleting` from Settings.
  static Future<bool> showDeletePlaylist(
    BuildContext context,
    Playlist playlist,
  ) async {    final bool confirmed =
        await confirmDialog(
          context,
          title: 'Delete "${playlist.name}"?',
          message: playlist.isEmpty
              ? 'This empty playlist will be removed permanently.'
              : 'This removes the playlist and its ${playlist.songCount} '
                  '${playlist.songCount == 1 ? 'song' : 'songs'}. Your '
                  'favourites and history are not affected.',
          confirmLabel: 'Delete',
          isDestructive: true,
        ) ??
        false;

    if (!confirmed || !context.mounted) {
      return false;
    }

    final PlaylistProvider playlists = context.read<PlaylistProvider>();
    final bool ok = await playlists.delete(playlist.id);
    if (!context.mounted) {
      return ok;
    }
    showSnack(
      context,
      ok ? 'Playlist deleted.' : (playlists.errorMessage ?? 'Delete failed.'),
      isError: !ok,
    );
    return ok;
  }

  /// Overflow menu for a playlist row / header (spec §21).
  static Future<void> showPlaylistMenu(
    BuildContext context,
    Playlist playlist,
  ) async {
    final PlaylistProvider provider = context.read<PlaylistProvider>();
    final List<Song> songs = provider.songsFor(playlist);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: GlassSheetFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: AppDimensions.sm),
                Text(
                  playlist.name,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.md),
                _SheetAction(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (songs.isEmpty) {
                      showSnack(context, 'This playlist is empty.', isError: true);
                    } else {
                      context.read<PlayerProvider>().playQueue(songs);
                    }
                  },
                ),
                _SheetAction(
                  icon: Icons.shuffle_rounded,
                  label: 'Shuffle',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (songs.isEmpty) {
                      showSnack(context, 'This playlist is empty.', isError: true);
                    } else {
                      final PlayerProvider player = context.read<PlayerProvider>();
                      if (!player.shuffle) {
                        player.toggleShuffle();
                      }
                      player.playQueue(songs);
                    }
                  },
                ),
                _SheetAction(
                  icon: Icons.drive_file_rename_outline_rounded,
                  label: 'Rename',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(showPlaylistEditor(context, playlist: playlist));
                  },
                ),
                _SheetAction(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete playlist',
                  highlight: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(showDeletePlaylist(context, playlist));
                  },
                ),
                const SizedBox(height: AppDimensions.md),
              ],
            ),
          ),
        );
      },
    );
  }

  /// "Add to playlist" sheet (spec §21).
  static Future<void> showAddToPlaylistSheet(
    BuildContext context,
    Song song, {
    List<Song> playContext = const <Song>[],
  }) async {
    final PlaylistProvider playlists = context.read<PlaylistProvider>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return _AddToPlaylistSheet(
          song: song,
          playContext: playContext.isEmpty ? <Song>[song] : playContext,
        );
      },
    );
    if (!context.mounted) {
      return;
    }
    final String? message = playlists.errorMessage;
    if (message != null) {
      showSnack(context, message, isError: true);
      playlists.clearError();
    }
  }

  /// Overflow menu actions for a single track.
  static Future<void> showSongActions(
    BuildContext context,
    Song song, {
    List<Song> playContext = const <Song>[],
  }) async {
    final PlayerProvider player = context.read<PlayerProvider>();
    final LibraryProvider library = context.read<LibraryProvider>();
    final bool favorite = library.isFavorite(song.id);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: GlassSheetFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SheetHandle(),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        song.title,
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.md),
                    Text(
                      song.artist,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                _SheetAction(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play now',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(player.playFrom(
                      playContext.isEmpty ? <Song>[song] : playContext,
                      song,
                    ));
                  },
                ),
                _SheetAction(
                  icon: Icons.queue_play_next_rounded,
                  label: 'Play next',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(player.playQueue(<Song>[
                      if (player.hasQueue) ...player.queue,
                      song,
                    ]));
                  },
                ),
                _SheetAction(
                  icon: favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: favorite ? 'Remove from favourites' : 'Add to favourites',
                  highlight: favorite,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(library.toggleFavorite(song.id));
                  },
                ),
                _SheetAction(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to playlist',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(showAddToPlaylistSheet(context, song));
                  },
                ),
                _SheetAction(
                  icon: Icons.album_outlined,
                  label: 'Go to album',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(
                      Navigator.of(context).push(
                        fadeRoute(
                          AlbumDetailScreen(album: song.album),
                          name: AppRoutes.album,
                        ),
                      ),
                    );
                  },
                ),
                _SheetAction(
                  icon: Icons.person_outline_rounded,
                  label: 'Go to artist',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(
                      Navigator.of(context).push(
                        fadeRoute(
                          ArtistDetailScreen(artist: song.artist),
                          name: AppRoutes.artist,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Playback queue sheet (spec §13).
  static Future<void> showQueueSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => const _QueueSheet(),
    );
  }

  /// Generic destructive confirmation.
  static Future<bool?> confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final TextTheme text = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          title: Text(title),
          content: Text(message, style: text.bodyMedium),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: isDestructive
                    ? const Color(0xFFFF6B8A)
                    : VibeColors.electricBlue,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  /// Playback context menu shown from the now-playing screen.
  static Future<void> showPlaybackMenu(BuildContext context) async {
    final PlayerProvider player = context.read<PlayerProvider>();
    final Song? song = player.currentSong;
    if (song == null) {
      return;
    }
    await showSongActions(context, song);
  }

  /// Confirm then log out (spec §25).
  static Future<void> confirmLogout(BuildContext context) async {
    final bool confirmed = await confirmDialog(
          context,
          title: 'Log out?',
          message:
              'Your playlists, favourites and history stay saved on this device.',
          confirmLabel: 'Log out',
          isDestructive: true,
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }
    await context.read<AuthProvider>().logout();
  }

  /// Wipes the signed-in user's data without removing the account.
  static Future<void> confirmClearLocalData(BuildContext context) async {
    final bool confirmed = await confirmDialog(
          context,
          title: 'Clear local data?',
          message:
              'This deletes every playlist, favourite and history entry for '
              'this account on this device. Your account stays signed in.',
          confirmLabel: 'Clear data',
          isDestructive: true,
        ) ??
        false;
    if (!confirmed || !context.mounted) {
      return;
    }

    final PlaylistProvider playlists = context.read<PlaylistProvider>();
    final LibraryProvider library = context.read<LibraryProvider>();
    final SettingsProvider settings = context.read<SettingsProvider>();
    unawaited(settings.resetToDefaults());
    await playlists.clearAll();
    await library.clearHistory();
    await library.clearFavorites();
    if (!context.mounted) {
      return;
    }
    showSnack(context, 'Local data cleared.');
  }
}

// -----------------------------------------------------------------------------
// Private widgets
// -----------------------------------------------------------------------------

/// Glass frame shared by every bottom sheet body.
class GlassSheetFrame extends StatelessWidget {
  const GlassSheetFrame({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.8,
  });

  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VibeColors.secondaryBackground.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: VibeColors.glassBorder(1.2)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        size: 21,
        color: highlight ? VibeColors.neonPink : VibeColors.mutedText,
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: highlight ? VibeColors.softPink : VibeColors.white,
            ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 0,
      ),
    );
  }
}

class _PlaylistEditorDialog extends StatefulWidget {
  const _PlaylistEditorDialog({
    required this.playlist,
    required this.nameController,
    required this.descriptionController,
  });

  final Playlist? playlist;
  final TextEditingController nameController;
  final TextEditingController descriptionController;

  @override
  State<_PlaylistEditorDialog> createState() => _PlaylistEditorDialogState();
}

class _PlaylistEditorDialogState extends State<_PlaylistEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  Future<void> _submit() async {
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _submitting = true);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.playlist != null;
    return AlertDialog(
      title: Text(editing ? 'Rename playlist' : 'Create playlist'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: widget.nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Night Vibes',
              ),
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Playlist name cannot be empty.';
                }
                if (value.trim().length > 60) {
                  return 'Keep the name under 60 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppDimensions.lg),
            TextFormField(
              controller: widget.descriptionController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Late-night music',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(editing ? 'SAVE' : 'CREATE'),
        ),
      ],
    );
  }
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({required this.song, required this.playContext});

  final Song song;
  final List<Song> playContext;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaylistProvider>(
      builder: (
        BuildContext context,
        PlaylistProvider playlists,
        Widget? child,
      ) {
        return GlassSheetFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SheetHandle(),
              SheetHeader(
                title: 'Add to playlist',
                subtitle: song.title,
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: AppDimensions.md),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  unawaited(VibeActions.showPlaylistEditor(
                    context,
                    seedSongIds: <int>[song.id],
                  ));
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('NEW PLAYLIST'),
              ),
              const SizedBox(height: AppDimensions.md),
              if (playlists.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppDimensions.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (playlists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.xl),
                  child: Text(
                    'You have no playlists yet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: playlists.playlists.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Playlist playlist = playlists.playlists[index];
                      final bool contains =
                          playlists.containsSong(playlist.id, song.id);
                      return ListTile(
                        onTap: () async {
                          Navigator.pop(context);
                          final bool ok = contains
                              ? await playlists.removeSong(
                                  playlist.id,
                                  song.id,
                                )
                              : await playlists.addSong(playlist.id, song.id);
                          if (!context.mounted) {
                            return;
                          }
                          VibeActions.showSnack(
                            context,
                            ok
                                ? (contains
                                    ? 'Removed from "${playlist.name}".'
                                    : 'Added to "${playlist.name}".')
                                : (playlists.errorMessage ?? 'Could not update.'),
                            isError: !ok,
                          );
                          playlists.clearError();
                        },
                        leading: Icon(
                          contains
                              ? Icons.check_circle_rounded
                              : Icons.music_note_rounded,
                          color: contains
                              ? VibeColors.softPink
                              : VibeColors.mutedText,
                          size: 20,
                        ),
                        title: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        subtitle: Text('${playlist.songCount} songs'),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusChip),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (BuildContext context, PlayerProvider player, Widget? child) {
        final List<Song> queue = player.queue;
        return GlassSheetFrame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SheetHandle(),
              SheetHeader(
                title: 'Play queue',
                subtitle: queue.isEmpty
                    ? 'Nothing queued'
                    : '${player.queueIndex + 1} of ${queue.length}',
                onClose: () => Navigator.pop(context),
              ),
              const SizedBox(height: AppDimensions.sm),
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    VolumeControl(player: player),
                    if (queue.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.xxl,
                        ),
                        child: Text(
                          'Play something and the queue will appear here.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      for (int i = 0; i < queue.length; i++)
                        Dismissible(
                          key: ValueKey<String>('queue-${queue[i].id}-$i'),
                          direction: queue.length > 1
                              ? DismissDirection.endToStart
                              : DismissDirection.none,
                          onDismissed: (_) => player.removeFromQueue(i),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: AppDimensions.xl),
                            color: const Color(0xFFFF6B8A).withValues(alpha: 0.2),
                            child: const Icon(Icons.delete_outline_rounded),
                          ),
                          child: ListTile(
                            onTap: () {
                              unawaited(player.playQueue(queue, startIndex: i));
                            },
                            leading: SizedBox(
                              width: 24,
                              child: i == player.queueIndex
                                  ? const PlayingIndicator(isPlaying: true, size: 16)
                                  : Text(
                                      '${i + 1}',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                            ),
                            title: Text(
                              queue[i].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Text(queue[i].artist),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shown when the platform reports that an asset could not be played. Keeps the
/// error visible without spamming a SnackBar for every failed track.
class AudioErrorBanner extends StatelessWidget {
  const AudioErrorBanner({super.key, required this.player});

  final PlayerProvider player;

  @override
  Widget build(BuildContext context) {
    final String? message = player.errorMessage;
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        0,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Material(
        color: const Color(0xFFFF6B8A).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md,
            vertical: AppDimensions.sm,
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Color(0xFFFF8FA6),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFFC2CF),
                      ),
                ),
              ),
              IconButton(
                onPressed: player.clearError,
                iconSize: 18,
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable "greeting" header used by Home.
String greetingFor(DateTime now) {
  final int hour = now.hour;
  if (hour < 5) {
    return 'Still up';
  }
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 17) {
    return 'Good afternoon';
  }
  if (hour < 22) {
    return 'Good evening';
  }
  return 'Good night';
}

/// Resolves the catalog songs for an album name.
List<Song> songsForAlbum(String album) =>
    SongCatalog.all.where((Song s) => s.album == album).toList(growable: false);

/// Resolves the catalog songs for an artist name.
List<Song> songsForArtist(String artist) =>
    SongCatalog.all.where((Song s) => s.artist == artist).toList(growable: false);
