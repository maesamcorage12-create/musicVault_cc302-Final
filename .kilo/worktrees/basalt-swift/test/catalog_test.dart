import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:vibevault/data/song_catalog.dart';
import 'package:vibevault/models/song.dart';

/// Catalog integrity (spec §11, §12) plus the search filtering rules from
/// spec §18.
void main() {
  group('SongCatalog integrity', () {
    test('contains exactly 30 songs', () {
      expect(SongCatalog.all, hasLength(30));
    });

    test('ids are unique and 1-based', () {
      final List<int> ids =
          SongCatalog.all.map((Song song) => song.id).toList()..sort();
      expect(ids, List<int>.generate(30, (int i) => i + 1));
      expect(ids.toSet(), hasLength(30));
    });

    test('every song has the required metadata', () {
      for (final Song song in SongCatalog.all) {
        expect(song.title, isNotEmpty, reason: 'song ${song.id}');
        expect(song.artist, isNotEmpty, reason: 'song ${song.id}');
        expect(song.album, isNotEmpty, reason: 'song ${song.id}');
        expect(song.genre, isNotEmpty, reason: 'song ${song.id}');
        expect(song.duration.inMilliseconds, greaterThan(0));
      }
    });

    test('audioPath points at a file that exists on disk', () {
      for (final Song song in SongCatalog.all) {
        // Spec §12: the catalog string must exactly match the shipped file.
        final File file = File('assets/${song.audioPath}');
        expect(
          file.existsSync(),
          isTrue,
          reason: '${song.id}: assets/${song.audioPath} is missing',
        );
        expect(file.lengthSync(), greaterThan(0));
      }
    });

    test('catalog file names follow song_NN.mp3', () {
      for (final Song song in SongCatalog.all) {
        expect(
          song.audioPath,
          matches(RegExp(r'^audio/song_\d{2}\.mp3$')),
          reason: 'song ${song.id}',
        );
      }
    });

    test('there are no extra audio files on disk', () {
      final Directory dir = Directory('assets/audio');
      final List<String> onDisk = dir
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.toLowerCase().endsWith('.mp3'))
          .map((File f) => f.uri.pathSegments.last)
          .toList()
        ..sort();

      final List<String> inCatalog = SongCatalog.all
          .map((Song s) => s.audioPath.split('/').last)
          .toList()
        ..sort();

      expect(onDisk, inCatalog);
    });

    test('assetPath is prefixed with assets/', () {
      expect(SongCatalog.all.first.assetPath, startsWith('assets/'));
    });
  });

  group('lookups', () {
    test('byId resolves known ids and returns null otherwise', () {
      expect(SongCatalog.byId(1), isNotNull);
      expect(SongCatalog.byId(30), isNotNull);
      expect(SongCatalog.byId(0), isNull);
      expect(SongCatalog.byId(31), isNull);
    });

    test('resolve drops ids that are not in the catalog', () {
      final resolved = SongCatalog.resolve(<int>[1, 9999, 2]);
      expect(resolved.map((Song s) => s.id), <int>[1, 2]);
    });

    test('artists, albums and genres are unique and sorted', () {
      expect(SongCatalog.artists, orderedEquals(<String>[...SongCatalog.artists]..sort()));
      expect(SongCatalog.albums, orderedEquals(<String>[...SongCatalog.albums]..sort()));
      expect(SongCatalog.genres, orderedEquals(<String>[...SongCatalog.genres]..sort()));
      expect(SongCatalog.artists.length, lessThanOrEqualTo(30));
      expect(SongCatalog.artists.length, greaterThan(1));
    });

    test('every curated mix resolves to real songs', () {
      for (final PlaylistSeed seed in SongCatalog.curatedPlaylists) {
        expect(seed.title, isNotEmpty);
        expect(seed.genre, isNotNull);
        expect(
          SongCatalog.all.where((Song s) => s.genre == seed.genre),
          isNotEmpty,
          reason: 'no songs for genre ${seed.genre}',
        );
      }
    });
  });

  group('search haystack', () {
    test('matches on title, artist, album and genre', () {
      final Song song = SongCatalog.byId(1)!;

      expect(song.searchIndex, contains(song.title.toLowerCase()));
      expect(song.searchIndex, contains(song.artist.toLowerCase()));
      expect(song.searchIndex, contains(song.album.toLowerCase()));
      expect(song.searchIndex, contains(song.genre.toLowerCase()));
      expect(song.searchIndex, contains('${song.year}'));
    });

    test('a query matches every field the spec requires', () {
      List<Song> filter(String query) {
        final String needle = query.toLowerCase();
        return SongCatalog.all
            .where((Song song) => song.searchIndex.contains(needle))
            .toList();
      }

      final Song sample = SongCatalog.byId(4)!;

      expect(filter(sample.title), contains(sample));
      expect(filter(sample.artist), isNotEmpty);
      expect(filter(sample.album), isNotEmpty);
      expect(filter(sample.genre), isNotEmpty);
    });

    test('a query with no matches returns nothing', () {
      final results = SongCatalog.all
          .where((Song s) => s.searchIndex.contains('zzz-not-a-track'))
          .toList();
      expect(results, isEmpty);
    });
  });

  group('Song formatting', () {
    test('formatDuration renders minutes and seconds', () {
      expect(Song.formatDuration(const Duration(minutes: 3, seconds: 42)), '3:42');
      expect(Song.formatDuration(const Duration(seconds: 7)), '0:07');
      expect(Song.formatDuration(Duration.zero), '0:00');
    });

    test('formatDuration renders hours when needed', () {
      expect(
        Song.formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('formattedDuration uses the same helper', () {
      expect(SongCatalog.byId(1)!.formattedDuration, '0:24');
    });
  });
}