import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../models/song.dart';

/// Outcome of a load attempt. Kept as a sealed union so the provider can turn
/// it into either "playing" or a user-visible error (spec §30).
sealed class LoadOutcome {
  const LoadOutcome();

  /// Player-safe message, or `null` when the load succeeded.
  String? get message => null;
}

class LoadStarted extends LoadOutcome {
  const LoadStarted();
}

class LoadMissingAsset extends LoadOutcome {
  const LoadMissingAsset(this.song);

  final Song song;

  @override
  String get message => 'Audio file missing for "${song.title}".';
}

class LoadFailed extends LoadOutcome {
  const LoadFailed(this.song, this.cause);

  final Song song;
  final Object cause;

  @override
  String get message {
    final String detail = cause
        .toString()
        .replaceFirst('PlatformException(', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (detail.contains('not found') ||
        detail.contains('Unable to load asset')) {
      return 'Audio file missing for "${song.title}".';
    }
    return 'Could not play "${song.title}". $detail';
  }
}

/// Owns the application's single `AudioPlayer` instance (spec §14).
///
/// Every screen talks to `PlayerProvider`; nothing else constructs an
/// `AudioPlayer`. That is what keeps playback alive while navigating between
/// Home, Search, Library, the mini player and the full player.
class AudioService {
  AudioService() {
    _player.setReleaseMode(ReleaseMode.stop);
    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _player.onPositionChanged.listen(_positionController.add),
      _player.onDurationChanged.listen(_durationController.add),
      _player.onPlayerStateChanged.listen(_stateController.add),
      _player.onPlayerComplete.listen((_) => _completeController.add(null)),
      _player.onLog.listen(_handleLog),
    ]);
  }

  final AudioPlayer _player = AudioPlayer();

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();

  /// Human readable platform diagnostics (audioplayers logs errors here).
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Stream<String> get diagnostics => _logController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<PlayerState> get playerStateStream => _stateController.stream;
  Stream<void> get completeStream => _completeController.stream;

  PlayerState get playerState => _player.state;
  bool get isPlaying => _player.state == PlayerState.playing;

  void _handleLog(String message) {
    if (message.isEmpty) {
      return;
    }
    final String lower = message.toLowerCase();
    if (lower.contains('error') ||
        lower.contains('exception') ||
        lower.contains('not found') ||
        lower.contains('unable to')) {
      _logController.add(message);
    }
  }

  /// Hands the asset to the platform player. Lets the platform report errors
  /// natively, which audioplayers surfaces via the log stream.
  Future<LoadOutcome> load(
    Song song, {
    Duration initialPosition = Duration.zero,
  }) async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(AssetSource(song.audioPath));
      await _player.setVolume(_volume);
      if (initialPosition > Duration.zero) {
        await _player.seek(initialPosition);
      }
      return const LoadStarted();
    } on Object catch (error) {
      final String detail = error.toString();
      if (detail.contains('not found') ||
          detail.contains('Unable to load') ||
          detail.contains('Unable to resolve')) {
        return LoadMissingAsset(song);
      }
      return LoadFailed(song, error);
    }
  }

  double _volume = 1;

  /// Starts (or resumes) the source that was loaded most recently.
  Future<void> play() async {
    try {
      await _player.resume();
    } on Object catch (error) {
      _logController.add(error.toString());
    }
  }

  Future<void> pause() => _player.pause();

  /// Resumes playback of the currently loaded source.
  Future<void> resume() => _player.resume();

  Future<void> stop() async {
    try {
      await _player.stop();
    } on Object catch (_) {
      // Stopping an already-stopped player is not an error worth surfacing.
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } on Object catch (_) {
      // Seeking is best effort on some platforms.
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
    } on Object catch (_) {
      // ignore
    }
  }

  Future<void> setSpeed(double speed) => _player.setPlaybackRate(speed);

  Future<Duration> currentPosition() async =>
      await _player.getCurrentPosition() ?? Duration.zero;

  Future<Duration> currentDuration() async =>
      await _player.getDuration() ?? Duration.zero;

  Future<void> dispose() async {
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _positionController.close();
    await _durationController.close();
    await _stateController.close();
    await _completeController.close();
    await _logController.close();
    await _player.dispose();
  }
}
