import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'repositories/playback_repository.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Settings are read once up front so the first painted frame already uses the
  // saved background quality (no flash of the wrong render budget).
  final StorageService storage = StorageService();
  AppSettings settings = const AppSettings();
  try {
    settings = await SettingsRepository(storage).load();
  } on Object catch (_) {
    // A broken settings blob must not stop the app from starting.
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(VibeVaultApp(storage: storage, initialSettings: settings));
}
