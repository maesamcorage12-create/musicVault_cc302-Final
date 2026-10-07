import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/playback_state.dart';
import '../models/song.dart';
import '../repositories/playback_repository.dart';
import '../services/audio_service.dart';
import 'library_provider.dart';

enum PlaybackStatus { idle, loading, ready, error }

/// The single source of truth for audio playback (spec §13, §14).
///
/// There is exactly one `AudioPlayer` in the app, created by [AudioService] and
/// driven from here. Home, Search, Library, Playlists, the mini player and the
/// full player all read this object, so playback is never interrupted by
/// navigation.
class PlayerProvider extends ChangeNotifier {
  PlayerProvider(this._audio, this._playbackRepository) {
    _subscriptions.add(
      _audio.positionStream.listen((Duration value) => position.value = value),
    );
    _subscriptions.add(
      _audio.durationStream.listen((Duration value) => duration.value = value),
    );
    _subscriptions.add(
      _audio.playerStateStream.listen((PlayerState state) {
        _setPlaying(state == PlayerState.playing);
        _notify();
      }),
    );
    _subscriptions.add(
      _audio.completeStream.listen((_) => unawaited(_handleComplete())),
    );
    _subscriptions.add(_audio.diagnostics.listen(_onPlatformError));
  }

  final AudioService _audio;
  final PlaybackRepository _playbackRepository;
  final math.Random _random = math.Random();

  /// High-frequency playback clock. Exposed as a [ValueNotifier] instead of via
  /// `notifyListeners` so the progress bar can repaint at ~10 Hz without
  /// rebuilding the whole app shell.
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> duration =
      ValueNotifier<Duration>(Duration.zero);

  final List<Song> _queue = <Song>[];
  final List<Song> _preShuffleQueue = <Song>[];

  int _index = -1;
  bool _isPlaying = false;
  PlaybackStatus _status = PlaybackStatus.idle;
  String? _errorMessage;
  bool _shuffle = false;
  RepeatMode _repeatMode = RepeatMode.off;
  double _volume = 1;

  String? _userId;
  LibraryProvider? _library;

  // Listening-time bookkeeping (feeds LibraryProvider.finalizePlay).
  DateTime? _playStartedAt;
  Duration _pendingListen = Duration.zero;

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Timer? _persistDebounce;
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Public state
  // ---------------------------------------------------------------------------

  PlaybackStatus get status => _status;
  bool get isPlaying => _isPlaying;
  bool get isBusy => _status == PlaybackStatus.loading;
  String? get errorMessage => _errorMessage;

  bool get shuffle => _shuffle;
  RepeatMode get repeatMode => _repeatMode;
  double get volume => _volume;

  List<Song> get queue => List<Song>.unmodifiable(_queue);
  int get queueIndex => _index;
  int get queueLength => _queue.length;
  bool get hasQueue => _queue.isNotEmpty && _index >= 0;

  Song? get currentSong => hasQueue ? _queue[_index] : null;
  bool get hasSong => currentSong != null;

  Song? get nextSong {
    final int? target = _peekNext();
    return target == null ? null : _queue[target];
  }

  Song? get previousSong {
    if (!hasQueue) {
      return null;
    }
    final int target = _index - 1 < 0 ? _queue.length - 1 : _index - 1;
    return _queue[target];
  }

  Duration get currentPosition => position.value;

  Duration get totalDuration {
    if (duration.value > Duration.zero) {
      return duration.value;
    }
    return currentSong?.duration ?? Duration.zero;
  }

  double get progress {
    final int total = totalDuration.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return (position.value.inMilliseconds / total).clamp(0.0, 1.0);
  }

  bool get hasNext => _peekNext() != null;
  bool get hasPrevious => hasQueue;

  // ---------------------------------------------------------------------------
  // Wiring (called from the provider tree, never from a widget)
  // ---------------------------------------------------------------------------

  /// Associates the player with the signed-in account and restores that
  /// account's mode settings.
  ///
  /// Called from `ChangeNotifierProxyProvider.update`, i.e. during the build
  /// phase, so signing out defers the teardown: `position` is a ValueNotifier
  /// and mutating it here would call `setState` on a still-mounted mini player
  /// while Flutter is building.
  void bindUser(String? userId) {
    if (_userId == userId) {
      return;
    }
    _userId = userId;
    if (userId == null) {
      _persistDebounce?.cancel();
      scheduleMicrotask(() {
        if (_disposed || _userId != null) {
          return;
        }
        unawaited(_stopInternal());
        _resetQueue();
        _notify();
      });
      return;
    }
    unawaited(_restoreSettings(userId));
  }

  void bindLibrary(LibraryProvider? library) => _library = library;

  Future<void> _restoreSettings(String userId) async {
    try {
      final PlaybackState stored = await _playbackRepository.load(userId);
      if (_userId != userId) {
        return;
      }
      _shuffle = stored.shuffle;
      _repeatMode = stored.repeatMode;
      _volume = stored.volume.clamp(0.0, 1.0);
      await _audio.setVolume(_volume);
      _notify();
    } on Object catch (_) {
      // Defaults are already in place; a failed restore is not fatal.
    }
  }

  void _persist() {
    final String? userId = _userId;
    if (userId == null || _disposed) {
      return;
    }
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 700), () {
      final PlaybackState snapshot = PlaybackState(
        shuffle: _shuffle,
        repeatMode: _repeatMode,
        volume: _volume,
        lastSongId: currentSong?.id,
        lastPositionMs: position.value.inMilliseconds,
      );
      unawaited(
        _playbackRepository
            .save(userId, snapshot)
            .catchError((Object _) {}),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Queue control
  // ---------------------------------------------------------------------------

  /// Replaces the queue and starts playing at [startIndex].
  Future<void> playQueue(
    List<Song> songs, {
    int startIndex = 0,
    bool autoplay = true,
    Duration initialPosition = Duration.zero,
  }) async {
    if (songs.isEmpty) {
      _status = PlaybackStatus.error;
      _errorMessage = 'There is nothing to play here yet.';
      _notify();
      return;
    }
    _commitListen(completed: false, keepTracking: false);
    _queue
      ..clear()
      ..addAll(songs);
    _preShuffleQueue
      ..clear()
      ..addAll(songs);
    _index = startIndex.clamp(0, songs.length - 1);
    if (_shuffle && songs.length > 1) {
      _applyShuffleOrder();
    }
    await _loadCurrent(initialPosition: initialPosition, autoplay: autoplay);
  }

  /// Plays [song] within its surrounding list so next/previous walk the list.
  Future<void> playFrom(List<Song> context, Song song) async {
    final int index = context.indexWhere((Song s) => s.id == song.id);
    if (index < 0) {
      await playQueue(<Song>[song]);
      return;
    }
    await playQueue(context, startIndex: index);
  }

  /// Plays a single track, leaving no continuation.
  Future<void> playSingle(Song song) =>
      playQueue(<Song>[song], startIndex: 0);

  Future<void> togglePlayPause() async {
    if (!hasSong) {
      if (_status != PlaybackStatus.error) {
        _status = PlaybackStatus.error;
        _errorMessage = 'Pick a song to start listening.';
        _notify();
      }
      return;
    }
    if (_isPlaying) {
      await pause();
      return;
    }
    if (_status == PlaybackStatus.error) {
      // Recover from an earlier load failure.
      await _loadCurrent(autoplay: true, resumeFrom: position.value);
      return;
    }
    if (_audio.playerState == PlayerState.paused ||
        _audio.playerState == PlayerState.playing) {
      await _audio.resume();
      _startTracking();
      _setPlaying(true);
      _notify();
      return;
    }
    await _loadCurrent(autoplay: true, resumeFrom: position.value);
  }

  Future<void> pause() async {
    if (!hasSong) {
      return;
    }
    await _audio.pause();
    _setPlaying(false);
    _commitListen(completed: false, keepTracking: false);
    _notify();
    _persist();
  }

  Future<void> stop() async {
    if (!hasSong) {
      return;
    }
    _commitListen(completed: false, keepTracking: false);
    await _audio.stop();
    position.value = Duration.zero;
    _setPlaying(false);
    _status = PlaybackStatus.ready;
    _notify();
    _persist();
  }

  /// Manual next.
  Future<void> next() async {
    if (!hasQueue) {
      return;
    }
    _commitListen(completed: false, keepTracking: false);
    final int? target = _peekNext();
    if (target == null) {
      await _audio.stop();
      position.value = Duration.zero;
      _setPlaying(false);
      _status = PlaybackStatus.ready;
      _notify();
      return;
    }
    _index = target;
    await _loadCurrent(autoplay: _wasPlayingBeforeStop);
  }

  /// Manual previous. Restarts the current track when it is more than 3s in.
  Future<void> previous() async {
    if (!hasQueue) {
      return;
    }
    if (position.value > const Duration(seconds: 3)) {
      await seekTo(Duration.zero);
      return;
    }
    _commitListen(completed: false, keepTracking: false);
    _index = _index - 1 < 0 ? _queue.length - 1 : _index - 1;
    await _loadCurrent(autoplay: _wasPlayingBeforeStop);
  }

  Future<void> seekTo(Duration value) async {
    final Duration total = totalDuration;
    final Duration clamped = value < Duration.zero
        ? Duration.zero
        : (total > Duration.zero && value > total ? total : value);
    position.value = clamped;
    if (hasSong) {
      try {
        await _audio.seek(clamped);
      } on Object catch (_) {
        // Seeking is best effort on some platforms.
      }
    }
    _persist();
  }

  Future<void> skipBy(Duration delta) => seekTo(position.value + delta);

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    try {
      await _audio.setVolume(_volume);
    } on Object catch (_) {
      // ignore
    }
    _notify();
    _persist();
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle && _queue.length > 1) {
      _applyShuffleOrder();
    } else {
      final Song? playing = currentSong;
      _queue
        ..clear()
        ..addAll(_preShuffleQueue);
      if (playing == null) {
        _index = _queue.isEmpty ? -1 : 0;
      } else {
        final int restored = _queue.indexWhere((Song s) => s.id == playing.id);
        _index = restored >= 0 ? restored : 0;
      }
    }
    _notify();
    _persist();
  }

  void cycleRepeatMode() {
    _repeatMode = _repeatMode.next;
    _notify();
    _persist();
  }

  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
    _notify();
    _persist();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    if (_status == PlaybackStatus.error) {
      _status = hasSong ? PlaybackStatus.ready : PlaybackStatus.idle;
    }
    _notify();
  }

  /// Drops a queued track. Removing the playing track advances to the next one.
  void removeFromQueue(int queuePosition) {
    if (queuePosition < 0 ||
        queuePosition >= _queue.length ||
        _queue.length <= 1) {
      return;
    }
    final bool removingCurrent = queuePosition == _index;
    final Song removed = _queue.removeAt(queuePosition);
    _preShuffleQueue.removeWhere((Song s) => s.id == removed.id);

    if (!removingCurrent) {
      if (queuePosition < _index) {
        _index--;
      }
      _notify();
      return;
    }

    _commitListen(completed: false, keepTracking: false);
    _index = queuePosition.clamp(0, _queue.length - 1);
    unawaited(_loadCurrent(autoplay: _wasPlayingBeforeStop));
  }

  void clearQueue() {
    _commitListen(completed: false, keepTracking: false);
    _resetQueue();
    _notify();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Remembers whether playback was running before a track change, so "next"
  /// after a pause stays paused instead of surprising the user with audio.
  bool get _wasPlayingBeforeStop => _isPlaying;

  void _resetQueue() {
    _queue.clear();
    _preShuffleQueue.clear();
    _index = -1;
    position.value = Duration.zero;
    duration.value = Duration.zero;
    _isPlaying = false;
    _status = PlaybackStatus.idle;
    _playStartedAt = null;
    _pendingListen = Duration.zero;
  }

  void _applyShuffleOrder() {
    final Song? current = currentSong;
    final List<Song> rest = _queue
        .where((Song s) => s.id != current?.id)
        .toList(growable: false)
      ..shuffle(_random);
    final List<Song> rebuilt = <Song>[
      if (current != null) current,
      ...rest,
    ];
    _queue
      ..clear()
      ..addAll(rebuilt);
    _index = current == null ? (_queue.isEmpty ? -1 : 0) : 0;
  }

  /// Resolves the next queue index, or `null` when the queue is exhausted.
  int? _peekNext() {
    if (!hasQueue) {
      return null;
    }
    if (_index + 1 < _queue.length) {
      return _index + 1;
    }
    return _repeatMode == RepeatMode.all ? 0 : null;
  }

  void _startTracking() => _playStartedAt = DateTime.now();

  /// Flushes the seconds listened since the last commit into the library.
  void _commitListen({required bool completed, required bool keepTracking}) {
    final Song? song = currentSong;
    final DateTime? startedAt = _playStartedAt;
    if (song == null || startedAt == null) {
      _playStartedAt = null;
      _pendingListen = Duration.zero;
      return;
    }
    _pendingListen += DateTime.now().difference(startedAt);
    _playStartedAt = keepTracking ? DateTime.now() : null;
    final Duration listened = _pendingListen;
    _pendingListen = Duration.zero;
    unawaited(_library?.finalizePlay(song.id, listened, completed: completed));
  }

  Future<void> _loadCurrent({
    required bool autoplay,
    Duration initialPosition = Duration.zero,
    Duration? resumeFrom,
  }) async {
    final Song? song = currentSong;
    if (song == null) {
      return;
    }

    _status = PlaybackStatus.loading;
    _errorMessage = null;
    duration.value = song.duration;
    position.value = initialPosition;
    _notify();

    final LoadOutcome outcome =
        await _audio.load(song, initialPosition: initialPosition);
    if (_disposed || currentSong?.id != song.id) {
      return; // Queue changed while loading — drop this result.
    }

    switch (outcome) {
      case LoadMissingAsset():
      case LoadFailed():
        _status = PlaybackStatus.error;
        _errorMessage = outcome.message;
        _setPlaying(false);
      case LoadStarted():
        _status = PlaybackStatus.ready;
        if (resumeFrom != null && resumeFrom > Duration.zero) {
          await _audio.seek(resumeFrom);
          position.value = resumeFrom;
        }
        if (autoplay) {
          _startTracking();
          unawaited(_audio.play());
          _setPlaying(true);
          unawaited(_library?.recordPlay(song.id));
        }
    }
    _notify();
    _persist();
  }

  Future<void> _stopInternal() async {
    _commitListen(completed: false, keepTracking: false);
    await _audio.stop();
    position.value = Duration.zero;
    _setPlaying(false);
  }

  /// Fires when the decoder reaches the end of the track (spec §37
  /// "Audio completion").
  Future<void> _handleComplete() async {
    final Song? song = currentSong;
    if (song != null) {
      position.value = totalDuration;
      _commitListen(completed: true, keepTracking: false);
    } else {
      position.value = Duration.zero;
    }

    if (_repeatMode == RepeatMode.one && song != null) {
      await _loadCurrent(autoplay: true);
      return;
    }

    final int? target = _peekNext();
    if (target == null) {
      await _audio.stop();
      position.value = Duration.zero;
      _setPlaying(false);
      _status = PlaybackStatus.ready;
      _notify();
      _persist();
      return;
    }
    _index = target;
    await _loadCurrent(autoplay: true);
  }

  void _onPlatformError(String message) {
    if (_disposed) {
      return;
    }
    _status = PlaybackStatus.error;
    _errorMessage = message;
    _setPlaying(false);
    _notify();
  }

  void _setPlaying(bool value) => _isPlaying = value;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _persistDebounce?.cancel();
    _commitListen(completed: false, keepTracking: false);
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    position.dispose();
    duration.dispose();
    super.dispose();
  }
}
