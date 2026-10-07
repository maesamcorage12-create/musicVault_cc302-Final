import 'package:flutter_test/flutter_test.dart';

import 'package:vibevault/models/playback_state.dart';
import 'package:vibevault/models/playlist.dart';
import 'package:vibevault/models/song.dart';
import 'package:vibevault/models/user.dart';
import 'package:vibevault/repositories/playback_repository.dart';

/// Model-level tests, including the repeat-mode cycle from spec §13.
void main() {
  group('RepeatMode', () {
    test('cycles off → all → one → off', () {
      expect(RepeatMode.off.next, RepeatMode.all);
      expect(RepeatMode.all.next, RepeatMode.one);
      expect(RepeatMode.one.next, RepeatMode.off);
    });

    test('exposes human labels', () {
      expect(RepeatMode.off.label, 'Repeat off');
      expect(RepeatMode.all.shortLabel, 'All');
      expect(RepeatMode.one.shortLabel, 'One');
    });

    test('parses from a stored name and falls back safely', () {
      expect(RepeatMode.fromName('one'), RepeatMode.one);
      expect(RepeatMode.fromName('nonsense'), RepeatMode.off);
      expect(RepeatMode.fromName(null), RepeatMode.off);
    });
  });

  group('PlaybackState', () {
    test('round-trips through JSON', () {
      const PlaybackState state = PlaybackState(
        shuffle: true,
        repeatMode: RepeatMode.one,
        volume: 0.42,
        lastSongId: 12,
        lastPositionMs: 9000,
      );

      final decoded = PlaybackState.fromJson(state.toJson());

      expect(decoded.shuffle, isTrue);
      expect(decoded.repeatMode, RepeatMode.one);
      expect(decoded.volume, closeTo(0.42, 0.0001));
      expect(decoded.lastSongId, 12);
      expect(decoded.lastPositionMs, 9000);
    });

    test('clamps an out-of-range stored volume', () {
      final decoded = PlaybackState.fromJson(<String, dynamic>{
        'volume': 4.2,
      });
      expect(decoded.volume, 1.0);
    });
  });

  group('BackgroundQuality', () {
    test('higher quality means more work', () {
      expect(
        BackgroundQuality.low.pillarCount,
        lessThan(BackgroundQuality.medium.pillarCount),
      );
      expect(
        BackgroundQuality.medium.pillarCount,
        lessThan(BackgroundQuality.high.pillarCount),
      );
      expect(
        BackgroundQuality.low.particleCount,
        lessThan(BackgroundQuality.high.particleCount),
      );
      expect(
        BackgroundQuality.low.cycleDuration,
        greaterThan(BackgroundQuality.high.cycleDuration),
      );
    });

    test('parses from a stored name', () {
      expect(BackgroundQuality.fromName('low'), BackgroundQuality.low);
      expect(BackgroundQuality.fromName('bogus'), BackgroundQuality.high);
    });
  });

  group('AppSettings', () {
    test('round-trips through JSON', () {
      const AppSettings settings = AppSettings(
        backgroundQuality: BackgroundQuality.low,
        reduceMotion: true,
        confirmBeforeDeleting: false,
      );

      final decoded = AppSettings.fromJson(settings.toJson());

      expect(decoded.backgroundQuality, BackgroundQuality.low);
      expect(decoded.reduceMotion, isTrue);
      expect(decoded.confirmBeforeDeleting, isFalse);
    });
  });

  group('Playlist model', () {
    test('withSong does not duplicate', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Mix',
        songIds: const <int>[1],
        createdAt: DateTime(2026),
      );

      expect(playlist.withSong(1).songIds, <int>[1]);
      expect(playlist.withSong(2).songIds, <int>[1, 2]);
      expect(playlist.songCount, 1);
    });

    test('withoutSong removes and reports the change', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Mix',
        songIds: const <int>[1, 2],
        createdAt: DateTime(2026),
      );

      expect(playlist.withoutSong(2).songIds, <int>[1]);
      expect(playlist.withoutSong(99).songIds, <int>[1, 2]);
    });

    test('totalSeconds sums the durations from the supplied lookup', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Mix',
        songIds: const <int>[1, 2],
        createdAt: DateTime(2026),
      );

      expect(
        playlist.totalSeconds(secondsById: const <int, int>{1: 30, 2: 45}),
        75,
      );
      expect(playlist.totalSeconds(secondsById: const <int, int>{1: 30}), 30);
    });

    test('round-trips through JSON', () {
      final playlist = Playlist(
        id: 'p1',
        name: 'Mix',
        description: 'desc',
        songIds: const <int>[3, 1],
        createdAt: DateTime(2026, 3, 3),
        updatedAt: DateTime(2026, 3, 4),
        artworkSeed: 99,
      );

      final decoded = Playlist.fromJson(playlist.toJson());

      expect(decoded.id, 'p1');
      expect(decoded.name, 'Mix');
      expect(decoded.description, 'desc');
      expect(decoded.songIds, <int>[3, 1]);
      expect(decoded.artworkSeed, 99);
      expect(decoded.updatedAt, DateTime(2026, 3, 4));
    });

    test('songIds are unmodifiable so accidental edits cannot leak', () {
      final playlist = Playlist.fromJson(<String, dynamic>{
        'id': 'p1',
        'name': 'Mix',
        'songIds': <int>[1],
        'createdAt': DateTime(2026).toIso8601String(),
      });

      expect(() => playlist.songIds.add(2), throwsUnsupportedError);
    });
  });

  group('User model', () {
    test('initials derive from the username', () {
      User user(String name) => User(
            id: 'u1',
            username: name,
            email: 'a@b.co',
            passwordHash: '',
            createdAt: DateTime(2026),
          );

      expect(user('Ada Lovelace').initials, 'AL');
      expect(user('prince').initials, 'P');
      expect(user('   ').initials, '?');
    });

    test('withoutSecret strips the password digest', () {
      final user = User(
        id: 'u1',
        username: 'Ada',
        email: 'a@b.co',
        passwordHash: 'digest',
        createdAt: DateTime(2026),
      );

      expect(user.withoutSecret().passwordHash, isEmpty);
      expect(user.withoutSecret().username, 'Ada');
    });
  });

  group('Song model', () {
    test('round-trips through JSON', () {
      const song = Song(
        id: 7,
        title: 'City Lights',
        artist: 'Neon Harbor',
        album: 'After Dark',
        genre: 'Electronic',
        audioPath: 'audio/song_07.mp3',
        duration: Duration(milliseconds: 25161),
        year: 2024,
        description: 'desc',
      );

      final decoded = Song.fromJson(song.toJson());

      expect(decoded.id, 7);
      expect(decoded.title, 'City Lights');
      expect(decoded.duration, song.duration);
      expect(decoded.year, 2024);
      expect(decoded.description, 'desc');
    });

    test('optional fields are omitted when absent', () {
      const song = Song(
        id: 1,
        title: 'T',
        artist: 'A',
        album: 'Al',
        genre: 'G',
        audioPath: 'audio/song_01.mp3',
        duration: Duration(seconds: 10),
      );

      expect(song.toJson().containsKey('year'), isFalse);
      expect(song.hasArtwork, isFalse);
      expect(song.copyWith(title: 'X').title, 'X');
      expect(song.copyWith(title: 'X').id, 1);
    });
  });
}