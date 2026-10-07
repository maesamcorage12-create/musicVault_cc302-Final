# VibeVault — Implementation Notes

This document explains *how* the app is assembled. For the feature list, the
architecture diagram and the test map, see `README.md`.

---

## Layer rules

The dependency direction is strictly one-way:

```text
screens/widgets  →  providers  →  repositories  →  StorageService
```

Rules that are actually enforced by the code:

1. **No widget touches `SharedPreferences`.** Screens call providers; providers
   call repositories; only repositories and `StorageService` do I/O.
2. **Exactly one `AudioPlayer`.** It lives in `AudioService`
   (`lib/services/audio_service.dart`) and is driven only by `PlayerProvider`.
   Constructing an `AudioPlayer` anywhere else would reintroduce the
   playback-restart bug that spec §14 exists to prevent.
3. **Statistics are never incremented by the UI.** `StatisticsProvider.derive`
   recomputes everything from the history list, so the numbers cannot drift away
   from real activity.

---

## Provider graph

`lib/app/app.dart` builds the whole graph in one `MultiProvider`:

```text
Provider<StorageService>
├── Provider<AuthRepository>
├── Provider<PlaylistRepository>
├── Provider<HistoryRepository>
├── Provider<FavoritesRepository>
├── Provider<PlaybackRepository>
├── Provider<SettingsRepository>
└── Provider<AudioService>

ChangeNotifierProvider<SettingsProvider>
ChangeNotifierProvider<AuthProvider>
ChangeNotifierProxyProvider<AuthProvider          → LibraryProvider>
ChangeNotifierProxyProvider<AuthProvider          → PlaylistProvider>
ChangeNotifierProxyProvider2<AuthProvider, LibraryProvider → PlayerProvider>
ChangeNotifierProxyProvider2<LibraryProvider, PlaylistProvider → StatisticsProvider>
```

### Why `syncUser` defers its notification

`ChangeNotifierProxyProvider.update` runs **during the build phase**. Calling
`notifyListeners()` there makes dependent widgets call `setState()` while the
tree is being built, which throws. So `LibraryProvider.syncUser`,
`PlaylistProvider.syncUser` and `StatisticsProvider` all follow the same rule:

```dart
void _scheduleNotify() {
  if (_disposed || _notifyScheduled) return;
  _notifyScheduled = true;
  scheduleMicrotask(() {
    _notifyScheduled = false;
    if (!_disposed) notifyListeners();
  });
}
```

`bind()`/`syncUser()` update state and schedule a notification; they never
notify inline. This is the single most common source of "setState() or
markNeedsBuild() called during build" in a `ProxyProvider` app, so it is worth
remembering when adding a provider.

---

## Player state machine

```text
                ┌──────────── playQueue / playFrom / playSingle
                ▼
        PlaybackStatus.loading
                │ LoadOutcome
   ┌────────────┼────────────┐
   ▼            ▼            ▼
  ready       error       (queue changed mid-load → drop)
   │  │
   │  └─ pause / stop / next / previous / completion
   ▼
idle (queue cleared or logged out)
```

* **Loading** sets `position` to the song's catalog duration so the UI has
  something sane while the platform prepares the source.
* **Errors** never throw at the UI: `AudioService.load` pre-flights
  `rootBundle.load` and returns `LoadMissingAsset` / `LoadFailed`, which the
  provider turns into `errorMessage`. `AppShell` surfaces each distinct message
  once as a SnackBar; the mini player keeps an inline banner.
* **`next` after a pause stays paused.** `_wasPlayingBeforeStop` is captured
  before the track changes, so pressing next while paused does not start audio.

### Listen-time bookkeeping

```dart
void _commitListen({required bool completed, required bool keepTracking}) { ... }
```

Called from `pause`, `stop`, `next`, `previous`, `removeFromQueue`, `dispose` and
`_handleComplete`. It accumulates the segment since `_playStartedAt`, writes it to
the library via `finalizePlay`, and either restarts the stopwatch
(`keepTracking: true`) or clears it.

---

## Persistence layout

Keys live in `StorageService`:

| Key | Contents |
| --- | --- |
| `vv:users` | `{version, accounts: {email: {id, username, email, salt, passwordHash, createdAt}}}` |
| `vv:session` | The signed-in user id |
| `vv:settings:app` | Device settings (background quality, reduce motion, …) |
| `vv:u:<userId>:playlists` | Playlist list |
| `vv:u:<userId>:favorites` | Favourite song ids, in insertion order |
| `vv:u:<userId>:history` | History entries, oldest first |
| `vv:u:<userId>:playback` | Shuffle / repeat / volume / last track |

Per-user key prefixes are what make two accounts on one device independent, and
they are also what `deleteAccount` wipes.

Reading is deliberately lenient and writing is strict:

* `PlaylistRepository.loadAll` drops unknown song ids and skips records that are
  not objects, so a catalog edit or a partially corrupted store cannot take the
  whole library down.
* `HistoryRepository` caps entries at 500, dropping oldest first.
* Write failures surface through `StorageException` → `errorMessage`, never as a
  crash.

---

## Adding a feature

1. **Model** — add or extend a class in `lib/models/` with `toJson`/`fromJson`
   and `copyWith`.
2. **Repository** — add the read/write to the matching repository. No
   `SharedPreferences` calls in the provider.
3. **Provider** — expose the state, mutate it through the repository, and report
   failures via `errorMessage` + `clearError()`.
4. **UI** — build the screen in `lib/screens/`, reuse the shared widgets, and
   always provide an empty state (`EmptyState`), a loading state
   (`LoadingView` / `SkeletonList`) and an error path (`InlineError`,
   `ErrorView` or a `VibeActions.showSnack`).
5. **Tests** — add coverage to the matching `test/` file.

### Regenerating imports

`tool/fix_imports.py` rebuilds every `lib/**.dart` import block from a
symbol → declaring-file table. It exists because the import set for a
provider-wired app is mechanical and easy to get wrong by hand:

```bash
python tool/fix_imports.py                    # regenerate
flutter analyze                               # then confirm 0 unused imports
```

It never rewrites code — only the import block — and it excludes self-imports,
respects a per-file `hide` table for names that clash with Material (the
project's `RepeatMode` versus Flutter's), and adds `as math` only where the
`math.` prefix is actually used.