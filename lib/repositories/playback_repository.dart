import 'dart:async';

import '../models/playback_state.dart';
import '../services/storage_service.dart';

/// Persists the player's mode settings and the last track/position so the app
/// can resume where the listener left off (spec §10 `PlaybackState`).
class PlaybackRepository {
  PlaybackRepository(this._storage);

  final StorageService _storage;

  String _key(String userId) => StorageService.userKey(userId, 'playback');

  Future<PlaybackState> load(String userId) async {
    final Map<String, dynamic>? raw =
        await _storage.readJsonObject(_key(userId));
    if (raw == null) {
      return const PlaybackState();
    }
    try {
      return PlaybackState.fromJson(raw);
    } on Object {
      return const PlaybackState();
    }
  }

  Future<void> save(String userId, PlaybackState state) =>
      _storage.writeJson(_key(userId), state.toJson());

  Future<void> clear(String userId) => _storage.remove(_key(userId));
}

/// Application-wide (device-level) preferences from the Settings screen
/// (spec §26). These are intentionally not per-user.
class SettingsRepository {
  SettingsRepository(this._storage);

  final StorageService _storage;

  String _key(String bucket) => 'vv:settings:$bucket';

  Future<AppSettings> load() async {
    final Map<String, dynamic>? raw =
        await _storage.readJsonObject(_key('app'));
    if (raw == null) {
      return const AppSettings();
    }
    try {
      return AppSettings.fromJson(raw);
    } on Object {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) =>
      _storage.writeJson(_key('app'), settings.toJson());
}

/// Immutable snapshot of the local settings.
class AppSettings {
  const AppSettings({
    this.backgroundQuality = BackgroundQuality.high,
    this.reduceMotion = false,
    this.confirmBeforeDeleting = true,
  });

  final BackgroundQuality backgroundQuality;

  /// Accessibility escape hatch: turns off decorative background motion.
  final bool reduceMotion;

  final bool confirmBeforeDeleting;

  AppSettings copyWith({
    BackgroundQuality? backgroundQuality,
    bool? reduceMotion,
    bool? confirmBeforeDeleting,
  }) {
    return AppSettings(
      backgroundQuality: backgroundQuality ?? this.backgroundQuality,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      confirmBeforeDeleting: confirmBeforeDeleting ?? this.confirmBeforeDeleting,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'backgroundQuality': backgroundQuality.name,
        'reduceMotion': reduceMotion,
        'confirmBeforeDeleting': confirmBeforeDeleting,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        backgroundQuality: BackgroundQuality.values.firstWhere(
          (BackgroundQuality q) => q.name == json['backgroundQuality'],
          orElse: () => BackgroundQuality.high,
        ),
        reduceMotion: (json['reduceMotion'] as bool?) ?? false,
        confirmBeforeDeleting: (json['confirmBeforeDeleting'] as bool?) ?? true,
      );
}

/// Background render budget offered by Settings (spec §4).
enum BackgroundQuality {
  low,
  medium,
  high;

  /// Pillars drawn by the LightPillar painter.
  int get pillarCount => switch (this) {
        BackgroundQuality.low => 3,
        BackgroundQuality.medium => 5,
        BackgroundQuality.high => 7,
      };

  /// Gaussian blur sigma for the pillar glow.
  double get blurSigma => switch (this) {
        BackgroundQuality.low => 24,
        BackgroundQuality.medium => 34,
        BackgroundQuality.high => 46,
      };

  /// Background particles.
  int get particleCount => switch (this) {
        BackgroundQuality.low => 12,
        BackgroundQuality.medium => 26,
        BackgroundQuality.high => 44,
      };

  /// Seconds per animation cycle.
  Duration get cycleDuration => switch (this) {
        BackgroundQuality.low => const Duration(seconds: 26),
        BackgroundQuality.medium => const Duration(seconds: 20),
        BackgroundQuality.high => const Duration(seconds: 16),
      };

  String get label => switch (this) {
        BackgroundQuality.low => 'Low',
        BackgroundQuality.medium => 'Medium',
        BackgroundQuality.high => 'High',
      };

  static BackgroundQuality fromName(String? name) => BackgroundQuality.values
      .firstWhere((BackgroundQuality q) => q.name == name,
          orElse: () => BackgroundQuality.high);
}
