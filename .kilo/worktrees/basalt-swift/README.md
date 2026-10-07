# VibeVault

A student-scale music streaming and playlist management application built
**100% with Flutter and Dart** — no React, no HTML/CSS/JS, no WebView UI, no
downloaded templates. The ReactBits-inspired LightPillar effect is recreated
natively with `CustomPainter` + `AnimationController` + `MaskFilter`.

> VibeVault is a Flutter-based, student-scale music streaming and playlist
> management application that allows users to locally create accounts, play a
> curated collection of 30 songs, search music, manage favorites and playlists,
> maintain listening history, and view personalized listening statistics
> through a responsive blue-and-pink glassmorphism interface.

---

## 1. What it does

| Area | Capability |
| --- | --- |
| **Accounts** | Local register / login / logout with session persistence across restarts |
| **Player** | One `AudioPlayer`, queue, play / pause / resume / stop, seek, volume, shuffle, repeat off/all/one |
| **Library** | Liked songs, playlists, albums, recently played |
| **Playlists** | Full CRUD, add/remove songs, play, shuffle, reorder |
| **Search** | Live filtering over title, artist, album and genre, with All/Songs/Artists/Albums filters |
| **History** | Every play recorded with listened seconds; feeds both Home and Profile |
| **Statistics** | Plays, listening time, top song, top genre, catalog coverage — all derived from real activity |
| **Settings** | Background quality, reduce motion, volume, clear history, clear local data, about |
| **Responsive** | Bottom navigation below 700 px, sidebar/rail at 700 px and up |

Everything is stored locally on the device through `SharedPreferences`. There is
no backend, no network call, and no analytics.

---

## 2. Running it

```bash
flutter pub get
flutter run                 # attached device or desktop
flutter run -d chrome       # web
```

### Checks before submission

```bash
flutter analyze             # 0 errors, 0 warnings, 0 info
flutter test                # 133 tests
flutter build apk --release # verified: build/app/outputs/flutter-apk/app-release.apk
flutter build web --release # verified
flutter build windows --release
```

> **Windows build note.** `flutter build windows` needs symlink support, which
> means Windows Developer Mode must be on (`start ms-settings:developers`).
> That is an environment setting, not a project problem — the Windows runner
> is committed and the Dart/asset pipeline is identical to the other targets.

> Note: the **Dart package name is `vibevault`** (see `pubspec.yaml`), so
> library imports read `package:vibevault/...`. The on-disk folder name is
> whatever you cloned into and does not affect the package name.

---

## 3. The 30-song catalog

`lib/data/song_catalog.dart` holds exactly 30 songs (spec §11), each with
`id`, `title`, `artist`, `album`, `genre`, `audioPath`, `duration`, `year` and
`description`.

```
Song
├── ID: 01
├── Title: Midnight Drive
├── Artist: Neon Harbor
├── Album: Night Sessions
├── Genre: Chill
├── Audio: audio/song_01.mp3   →  assets/audio/song_01.mp3
└── Duration: 0:24
```

The catalog spans 5 artists, 5 albums and 4 genres so search by artist, by album
and by genre all return meaningful results.

### Where the audio comes from

The repository ships 30 real, playable MP3 loops (~9 MiB total, ~25 s each) that
were synthesised locally by `tool/generate_audio.py`. They are placeholder
instrumentals — original, royalty-free, and generated from the same chord
recipes, tempi and instrumentation per genre.

```bash
python -m pip install numpy
python tool/generate_audio.py --ffmpeg <path-to-ffmpeg.exe>
```

The generator is deterministic: the same catalog id always produces the same
audio, so regenerating never creates spurious diffs. If you swap in real music,
replace the files in `assets/audio/` and update `duration` in
`song_catalog.dart` — nothing else needs to change.

`test/catalog_test.dart` asserts that every `audioPath` in the catalog points at
a file that exists on disk and that there are no extra audio files, which is the
spec §12 "filenames must match" rule enforced by CI rather than by hand.

---

## 4. Architecture

```text
UI (screens + widgets)
 ↓  provider / ChangeNotifier
Provider (state)
 ↓
Repository (domain rules)
 ↓
StorageService → SharedPreferences
```

Spec §34's separation is enforced throughout: no widget touches
`SharedPreferences`, and no provider talks to storage directly.

```text
lib/
├── main.dart                     bootstrap, reads settings before the first frame
├── app/
│   ├── app.dart                  MultiProvider graph + root router
│   ├── routes.dart               route names + fadeRoute transition
│   └── shell/app_shell.dart      responsive bottom nav / sidebar
├── theme/
│   ├── app_colors.dart           the single color system
│   ├── app_dimensions.dart       spacing, radii, breakpoints
│   └── app_theme.dart            Material 3 dark theme
├── models/                       Song, User, Playlist, HistoryEntry,
│                                 PlaybackState, ListeningStatistics
├── data/song_catalog.dart        the 30-song catalog + curated mixes
├── providers/                    Auth, Player, Library, Playlist,
│                                 Statistics, Settings
├── repositories/                 Auth, Playlist, History, Favorites,
│                                 Playback + device Settings
├── services/                     AudioService (the one AudioPlayer),
│                                 StorageService
├── screens/                      splash, auth, home, search, library,
│                                 favorites, playlists, player, profile,
│                                 statistics, settings, album, artist
└── widgets/                      glass_card, light_pillar_background,
                                  song_tile, album_card, playlist_card,
                                  mini_player, player_controls,
                                  empty_state, loading_view, …
```

### One audio player, one place

`AudioService` is the **only** class that constructs an `AudioPlayer`.
`PlayerProvider` owns queue, index, shuffle, repeat, position, duration and
volume, and every screen reads it. That is why navigation between Home, Search,
Library, the mini player and the full player never interrupts playback (spec §14).

Two details worth calling out:

* **Position is a `ValueNotifier`, not `notifyListeners`.** The progress bar
  repaints at ~10 Hz without rebuilding the app shell.
* **Play state is committed on real events.** `recordPlay` fires when a track
  starts; `finalizePlay` fires on pause, stop, skip and natural end, and stores
  the seconds actually heard. A track that is skipped immediately still counts
  as a play but adds almost no listening time.

### Provider wiring

`LibraryProvider` and `PlaylistProvider` are `ChangeNotifierProxyProvider`s over
`AuthProvider`, so signing in loads that account's data and signing out clears
it. Their `syncUser` methods run inside a build phase, so they **never notify
synchronously** — they defer with `scheduleMicrotask`. `StatisticsProvider`
applies the same deferral when its dependencies notify, which is what keeps
"setState during build" impossible.

---

## 5. Design system

Colors come from `VibeColors` only — no screen invents a hex value.

| Token | Value |
| --- | --- |
| Deep background | `#070A18` |
| Secondary background | `#10162B` |
| Electric blue | `#5227FF` |
| Bright blue | `#4DA6FF` |
| Neon pink | `#FF5DA2` |
| Soft pink | `#FF9FFC` |
| White | `#F8F7FF` |
| Muted text | `#A9AEC4` |

Primary gradient `#5227FF → #FF5DA2`, secondary `#4DA6FF → #FF9FFC`.
Cards are 22 px radius, buttons 16 px. The UI stays roughly 70 % dark, 20 % glass
and 10 % blue/pink accent.

### LightPillar background

```text
dark gradient wash
      ↓
blue light pillars (MaskFilter blur)
      ↓
purple transition + pink glow
      ↓
drifting particles
      ↓
vignette
```

It is drawn by `LightPillarPainter` behind an `IgnorePointer`, so it can never
intercept a tap, and it renders inside a `RepaintBoundary`. Settings exposes a
`Low / Medium / High` budget (pillar count, blur sigma, particle count, cycle
duration) plus a `Reduce motion` switch that freezes the animation for
accessibility.

---

## 6. What the tests cover

`flutter test` runs 133 tests across 9 files, mapped to the spec §37 checklist:

| File | Covers |
| --- | --- |
| `catalog_test.dart` | 30 songs, unique ids, `audioPath` ↔ file match, no extra audio, search haystack |
| `auth_repository_test.dart` | register, duplicate email, login, wrong password, plaintext check, session persistence, delete account, validation order |
| `playlist_repository_test.dart` | create / read / rename / delete, add / remove song, reorder, per-user scoping, corrupt-store tolerance, curated seeding |
| `history_repository_test.dart` | record play, patch listened seconds, dedup + ordering, per-user scoping, cap, restart persistence |
| `library_provider_test.dart` | favourites add/remove/persist, history recording, play counts, restart persistence |
| `statistics_test.dart` | totals, top song, top genre, genre share, zero-state |
| `models_test.dart` | repeat-mode cycle, JSON round-trips, playlist/song/user invariants |
| `widgets_test.dart` | color tokens, breakpoints, LightPillar at all three qualities, tap pass-through, glass cards, song tiles, empty/error states, mini player |
| `widget_test.dart` | app boot, splash → sign-in, form validation, invalid credentials |
| `shell_smoke_test.dart` | every destination at 390 px, 760 px and 1280 px, asserting no overflow and no render error |
| `capstone_flow_test.dart` | the spec 40 flow end to end: register, create a playlist, refuse a duplicate name, survive a restart, log out |

---

## 7. Honest limitations

* **Passwords** are stored as salted, stretched SHA-256 digests, never in plain
  text — but this is a school-project scheme, not production authentication.
  A real deployment needs a slow KDF (bcrypt / Argon2 / scrypt) server-side.
* **Storage** is `SharedPreferences`, so data is per-device and per-platform.
  Clearing app data or reinstalling removes it.
* **Statistics** are derived by walking the history on each recompute. At 30
  songs and a 500-entry history cap that is trivially cheap; it is not
  architected for a large catalog.
* **The bundled audio** is synthesised placeholder music, not commercial
  recordings.
* **Not built, on purpose:** real streaming APIs, cloud sync, social features,
  payments, subscriptions, recommendation engines. See spec §41.

---

## 8. Project status

* `flutter analyze` — clean (0 issues)
* `flutter test` — 133 passing
* `flutter build apk --release` — verified (60.3 MB)
* `flutter build web --release` — verified
* `flutter build windows --release` — blocked only by Windows Developer Mode being off on this machine; the runner is committed
* Every feature in the master specification is implemented