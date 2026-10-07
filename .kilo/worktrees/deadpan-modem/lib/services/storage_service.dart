import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, typed wrapper around `SharedPreferences`.
///
/// Every repository goes through this class so that:
///
/// * key naming stays consistent (`vv:<userId>:<bucket>`),
/// * JSON encode/decode errors surface as [StorageException] instead of
///   crashing the UI (spec §30),
/// * the `SharedPreferences` instance is only awaited once.
class StorageService {
  StorageService({SharedPreferences? preferences}) : _prefs = preferences;

  SharedPreferences? _prefs;

  /// Global (non user-scoped) keys.
  static const String keyUsers = 'vv:users';
  static const String keySession = 'vv:session';
  static const String keyAppSettings = 'vv:app-settings';
  static const String keyQuality = 'vv:background-quality';

  /// Per-user buckets.
  static String userKey(String userId, String bucket) => 'vv:u:$userId:$bucket';

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Injects a fake instance. Used by the widget/unit tests.
  // ignore: use_setters_to_change_properties
  void overrideInstance(SharedPreferences instance) => _prefs = instance;

  // ---------------------------------------------------------------------------
  // Primitive accessors
  // ---------------------------------------------------------------------------

  Future<String?> readString(String key) async =>
      (await _instance).getString(key);

  Future<bool> writeString(String key, String value) async {
    try {
      return await (await _instance).setString(key, value);
    } on Object catch (error) {
      throw StorageException('Could not save "$key"', error);
    }
  }

  Future<bool> remove(String key) async {
    try {
      return await (await _instance).remove(key);
    } on Object catch (error) {
      throw StorageException('Could not remove "$key"', error);
    }
  }

  Future<int?> readInt(String key) async => (await _instance).getInt(key);

  Future<double?> readDouble(String key) async => (await _instance).getDouble(key);

  Future<bool> readBool(String key, {bool fallback = false}) async =>
      (await _instance).getBool(key) ?? fallback;

  Future<bool> writeBool(String key, bool value) async {
    try {
      return await (await _instance).setBool(key, value);
    } on Object catch (error) {
      throw StorageException('Could not save "$key"', error);
    }
  }

  // ---------------------------------------------------------------------------
  // JSON helpers
  // ---------------------------------------------------------------------------

  /// Reads a JSON object. Returns `null` when absent; throws
  /// [StorageException] when the stored value is unreadable.
  Future<Map<String, dynamic>?> readJsonObject(String key) async {
    final String? raw = await readString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return decodeMap(raw, key);
  }

  Future<List<dynamic>> readJsonList(String key) async {
    final String? raw = await readString(key);
    if (raw == null || raw.isEmpty) {
      return const <dynamic>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded;
      }
      throw const FormatException('expected a JSON array');
    } on Object catch (error) {
      throw StorageException('Could not read "$key"', error);
    }
  }

  Future<bool> writeJson(String key, Object value) =>
      writeString(key, jsonEncode(value));

  /// Decodes a JSON object string, returning `null` instead of throwing when the
  /// payload is corrupt. Used by read paths that must survive bad data.
  static Map<String, dynamic>? decodeMapOrNull(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map<dynamic, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } on Object {
      return null;
    }
    return null;
  }

  static Map<String, dynamic> decodeMap(String raw, String key) {
    final Map<String, dynamic>? decoded = decodeMapOrNull(raw);
    if (decoded == null) {
      throw StorageException('Stored value for "$key" is not valid JSON');
    }
    return decoded;
  }

  /// Every key currently persisted. Used by "Clear local data".
  Future<Set<String>> allKeys() async => (await _instance).getKeys();

  Future<void> clear() async {
    try {
      await (await _instance).clear();
    } on Object catch (error) {
      throw StorageException('Could not clear local data', error);
    }
  }
}

/// Raised when persistence fails. UI layers catch this and show a message
/// rather than letting the error escape (spec §30).
class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
