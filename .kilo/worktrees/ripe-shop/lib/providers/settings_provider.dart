import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repositories/playback_repository.dart';

/// Device-level preferences from the Settings screen (spec §26).
///
/// This provider is not scoped to a user: appearance and audio preferences
/// belong to the device, not the account.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._repository);

  final SettingsRepository _repository;

  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  String? _errorMessage;

  AppSettings get settings => _settings;
  bool get isLoaded => _loaded;
  String? get errorMessage => _errorMessage;

  /// Seeds the provider with the settings already read during `main()`, so the
  /// first frame uses the right background quality without a flash.
  void applyInitial(AppSettings initial) {
    _settings = initial;
    _loaded = true;
  }

  BackgroundQuality get backgroundQuality => _settings.backgroundQuality;
  bool get reduceMotion => _settings.reduceMotion;
  bool get confirmBeforeDeleting => _settings.confirmBeforeDeleting;

  Future<void> load() async {
    try {
      _settings = await _repository.load();
      _errorMessage = null;
    } on Object catch (_) {
      _settings = const AppSettings();
      _errorMessage = 'Could not load settings.';
    } finally {
      _loaded = true;
      _notify();
    }
  }

  Future<void> setBackgroundQuality(BackgroundQuality quality) =>
      _update(_settings.copyWith(backgroundQuality: quality));

  Future<void> setReduceMotion(bool value) =>
      _update(_settings.copyWith(reduceMotion: value));

  Future<void> setConfirmBeforeDeleting(bool value) =>
      _update(_settings.copyWith(confirmBeforeDeleting: value));

  Future<void> setShowArtwork(bool value) =>
      _update(_settings.copyWith(showLyricStyleArtwork: value));

  Future<void> resetToDefaults() async {
    _settings = const AppSettings();
    _errorMessage = null;
    _notify();
    try {
      await _repository.save(_settings);
    } on Object catch (_) {
      _errorMessage = 'Could not save settings.';
      _notify();
    }
  }

  Future<void> _update(AppSettings next) async {
    _settings = next;
    _notify();
    try {
      await _repository.save(next);
      _errorMessage = null;
    } on Object catch (_) {
      _errorMessage = 'Could not save settings.';
      _notify();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }
    _errorMessage = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
