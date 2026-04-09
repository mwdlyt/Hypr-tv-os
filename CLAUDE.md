# CLAUDE.md

Guidance for AI assistants working in this repository. Read this before making changes.

## Project overview

**Hypr TV** is a free, open-source tvOS media player for Jellyfin servers — a modern
alternative to Infuse, Swiftfin, and the official Jellyfin client on Apple TV.
It uses VLCKit for universal codec/container support (MKV, HEVC, DTS-HD MA,
Dolby TrueHD, PGS subs, etc.) and talks to Jellyfin via its REST API.

- **Language**: Swift 5.9
- **UI**: SwiftUI (with a small UIKit bridge for the player)
- **Architecture**: MVVM + Observation (`@Observable`)
- **Concurrency**: Swift async/await and structured concurrency
- **Playback engine**: VLCKit (real framework on device; `VLCStub.swift` on Simulator)
- **Networking**: `URLSession` + Jellyfin REST API
- **Deployment target**: tvOS 17.0+
- **Xcode**: 15+
- **Bundle ID**: `com.hypr.tv`

## Build & run

The Xcode project is checked in (`HyprTV.xcodeproj`). There is also a
`project.yml` at the root, suggesting the project *can* be regenerated with
[XcodeGen](https://github.com/yonaskolb/XcodeGen), but the committed
`.xcodeproj` is the source of truth — do not blindly regenerate it.

1. Open `HyprTV.xcodeproj` in Xcode 15+.
2. Pick an Apple TV simulator or a real Apple TV device.
3. Build & run (Cmd+R).

### Debug credentials (skip login screen)

Set these environment variables in the Xcode scheme (or `launchEnvironment`
from UI tests) to auto-authenticate on launch — this is wired up in
`HyprTV/HyprTVApp.swift`:

- `HYPR_DEBUG_SERVER` — full server URL (e.g. `http://192.168.1.210:8096`)
- `HYPR_DEBUG_TOKEN` — an existing Jellyfin access token
- `HYPR_DEBUG_USERID` — the matching user ID

`HyprTVUITests/ScreenTourTests.swift` uses this same mechanism.

### Testing

- **UI test target**: `HyprTVUITests` — currently contains `ScreenTourTests.swift`,
  which drives the Siri Remote through every screen and captures screenshots.
- There is no unit-test target yet. Prefer adding new logic to types that are
  easy to test in isolation (view models, services) rather than stuffing
  behavior into views.

## Repository layout

```
Hypr-tv-os/
├── HyprTV.xcodeproj/              # Xcode project (committed; source of truth)
├── project.yml                    # Optional XcodeGen spec
├── HyprTV/                        # App sources
│   ├── HyprTVApp.swift            # @main, wires environment objects
│   ├── Info.plist                 # Bundle config, Bonjour, ATS
│   ├── Assets.xcassets/           # App icon, colors
│   ├── Preview Content/           # SwiftUI #Preview assets (excluded from build phase)
│   ├── Navigation/
│   │   ├── AppRouter.swift        # @Observable router, Destination enum, tabs
│   │   └── RootView.swift         # Auth gate → TabView(Home, Search, Settings)
│   ├── Models/                    # Plain Swift value types + @Observable settings
│   │   ├── AudioSettings.swift    # Audio output mode, lang prefs, boost
│   │   ├── MediaSegment.swift     # Intro/outro/recap/preview segments
│   │   ├── SavedServer.swift
│   │   ├── SubtitleStyle.swift
│   │   └── UserPolicy.swift       # Parental rating helpers
│   ├── Networking/
│   │   ├── JellyfinClient.swift   # Central @Observable HTTP client
│   │   ├── Endpoint.swift         # Enum describing every REST call
│   │   ├── AuthService.swift      # Login, logout, keychain session restore
│   │   ├── ServerDiscovery.swift  # UDP broadcast (port 7359) local discovery
│   │   └── DTOs/                  # Codable DTOs mirroring Jellyfin JSON
│   ├── Services/
│   │   ├── KeychainService.swift  # Typed wrapper over SecItem*
│   │   ├── ServerStore.swift      # UserDefaults-backed multi-server list
│   │   ├── UserDefaultsStore.swift
│   │   └── ImageLoader.swift      # actor; 3-tier: memory → disk → network
│   ├── ViewModels/                # One @Observable VM per screen
│   │   ├── HomeViewModel.swift
│   │   ├── LibraryViewModel.swift
│   │   ├── MediaDetailViewModel.swift
│   │   ├── PlayerViewModel.swift
│   │   ├── SearchViewModel.swift
│   │   ├── ServerConnectionViewModel.swift
│   │   └── UserProfileViewModel.swift
│   ├── Views/
│   │   ├── Components/            # Shared (AsyncPosterImage, ErrorView, LoadingView)
│   │   ├── Home/                  # HomeView + MediaRow, MediaCard, HeroBanner
│   │   ├── Library/               # LibraryView, AlphabetSidebar, FilterBar
│   │   ├── Detail/                # MediaDetailView, SeasonList, EpisodeRow, CastCrew
│   │   ├── Search/
│   │   ├── Player/                # PlayerView, OverlayView, Up Next, Skip, pickers
│   │   ├── ServerConnection/      # ServerConnectionView, ServerRow, ProfilePicker
│   │   └── Settings/              # SettingsView, AudioSettingsView
│   ├── Player/                    # VLC integration layer (see "Playback architecture")
│   │   ├── VLCPlayerWrapper.swift
│   │   ├── VLCPlayerViewController.swift
│   │   ├── VLCStub.swift          # Simulator-only fake VLC types
│   │   ├── PlayerRepresentable.swift
│   │   ├── PlayerLauncher.swift
│   │   ├── PlaybackCoordinator.swift
│   │   ├── RemoteCommandHandler.swift
│   │   └── MediaTrackPicker.swift
│   ├── Extensions/                # Data+Decode, URL+Jellyfin, View+TVFocus
│   └── Utilities/                 # Constants, Logger+Extensions, TimeFormatter
└── HyprTVUITests/
    └── ScreenTourTests.swift
```

## Architecture notes

### State & dependency injection

- The app uses the **Observation framework** (`@Observable`) — not
  `ObservableObject` / `@Published`. Prefer `@State` + `@Environment` with
  `@Observable` classes for everything that needs to cross view boundaries.
- Root-level environment objects are injected in `HyprTVApp.swift`:
  `AppRouter`, `JellyfinClient`, `AudioSettings`. Read them from views via
  `@Environment(JellyfinClient.self) private var jellyfinClient` etc.
- View models are typically constructed inside the owning view's `.task { … }`
  with the shared `JellyfinClient` passed in.

### Navigation

`AppRouter` (`HyprTV/Navigation/AppRouter.swift`) owns:
- Two `NavigationPath`s — one for the Home stack, one for the Search stack
  (Settings has no stack of its own).
- The `activeTab` enum (`.home | .search | .settings`).
- A weak-ish reference to `JellyfinClient` so it can launch the player from
  anywhere.

All navigation goes through `router.navigate(to: .mediaDetail(itemId:))` etc.
`.player(itemId:)` is a **special case** — it does **not** push a SwiftUI
screen; it invokes `PlayerLauncher.shared.launch(...)`, which presents a
UIKit modal outside the SwiftUI nav stack. See "Playback architecture" below.

### Networking

- `JellyfinClient` (`HyprTV/Networking/JellyfinClient.swift`) is the single
  entry point to Jellyfin. Every public method is `async throws`.
- The actual HTTP paths, methods, and query items live in `Endpoint.swift`
  as an enum so each REST call is defined in one place.
- Auth is via the `X-Emby-Authorization` header containing `Client`, `Device`,
  `DeviceId` (persistent UUID in UserDefaults), `Version`, and `Token`.
- `AuthService` wraps `JellyfinClient` for login, logout, and keychain-backed
  session restore. Credentials live in the keychain via `KeychainService`
  (service name `com.hypr.tv`, accessible `kSecAttrAccessibleAfterFirstUnlock`).
- Parental controls flow through `UserPolicy.maxParentalRating` — both the
  home-screen feed and library queries filter client-side as a safety net on
  top of server-side `MaxOfficialRating`.
- Server discovery uses UDP broadcast on port 7359 with payload
  `"who is JellyfinServer?"` — see `ServerDiscovery.swift`. Bonjour
  (`_jellyfin._tcp`) is also declared in `Info.plist`.

### DTOs

All Jellyfin DTOs live in `HyprTV/Networking/DTOs/`. Conventions:
- Codable structs with an explicit `CodingKeys` enum mapping `camelCase`
  Swift → `PascalCase` JSON.
- Optional fields stay optional — Jellyfin omits keys frequently.
- Enums (`MediaItemDTO.ItemType`, `MediaStreamDTO.StreamType`,
  `MediaSegment.SegmentType`) implement a custom `init(from:)` that falls back
  to `.unknown` rather than throwing, so unexpected values don't break
  decoding of otherwise-valid responses.
- Time values from Jellyfin are in **ticks** (1 tick = 100 ns,
  10_000_000 ticks = 1 second). `ms → ticks` is `* 10_000`.

### Playback architecture

This is the most subtle part of the codebase — read carefully before touching it.

```
AppRouter.playMedia(itemId:)
        │
        ▼
PlayerLauncher.shared.launch(itemId:, client:)
        │  Fetches MediaItemDTO, builds PlayerView,
        │  wraps in UIHostingController and present()s it
        │  modally (modalPresentationStyle = .fullScreen).
        ▼
PlayerView (SwiftUI)
 ├── PlayerRepresentable (UIViewControllerRepresentable)
 │      └── VLCPlayerViewController
 │             └── VLCPlayerWrapper.videoView  ← VLC draws frames here
 │
 ├── PlayerOverlayView        (transport, tracks, info)
 ├── SkipButton                (intro/outro/recap, from MediaSegment)
 └── UpNextOverlayView         (Netflix-style next-episode card)
```

Key rules:
1. **The player is NOT a SwiftUI navigation destination.** `AppRouter` bypasses
   its `NavigationPath` for `.player(...)` and calls `PlayerLauncher` instead.
   This was a deliberate fix — hosting VLC inside SwiftUI navigation caused
   menu-button and focus issues. Do not re-route it back through
   `navigationDestination`.
2. **`VLCPlayerWrapper` is the ONLY place that touches `VLCMediaPlayer`.**
   It is `@Observable` and republishes state (`isPlaying`, `isPaused`,
   `currentTimeMs`, `durationMs`, `audioTracks`, `subtitleTracks`, …) on the
   main actor. VLC delegate callbacks arrive on VLC's internal thread, so
   every mutation is dispatched via `DispatchQueue.main.async`.
3. **Simulator fallback.** `HyprTV/Player/VLCStub.swift` declares fake
   `VLCMedia`, `VLCMediaPlayer`, `VLCTime`, etc. so the Simulator build can
   compile and exercise the UI without the real VLCKit binary. The same file
   names shadow the real VLCKit types; make sure any new VLC-facing code
   compiles under both environments. The wrapper calls `setup()` lazily from
   `playURL(_:)`.
4. **Progress reporting.**
   - `PlayerViewModel.loadPlaybackInfo()` calls `getPlaybackInfo` and grabs
     a `playSessionId`.
   - `PlayerView` starts a 10-second ticker that calls
     `viewModel.reportProgress()` → `JellyfinClient.reportPlaybackProgress`.
   - Stop/pause lifecycle calls `reportPlaybackStart` / `reportPlaybackStopped`.
   - `PlaybackCoordinator` is an alternative reporting abstraction that
     owns its own timer; `JellyfinClient` conforms to `PlaybackReporting` so
     the coordinator can drive it. Currently `PlayerView` uses its own
     in-view ticker — do not accidentally double-report by wiring both.
5. **Stream URLs.** `JellyfinClient.streamURL(...)` returns a direct
   `/Videos/{id}/stream?static=true&api_key=…` URL. VLCKit direct-plays
   essentially everything, so the `DeviceProfile` sent in `getPlaybackInfo`
   is deliberately permissive. `streamURLHLS(...)` exists as an HLS
   transcoding fallback but is currently unused by the happy path.
6. **Media segments / skip buttons.** `MediaSegment` corresponds to the
   Jellyfin MediaSegments plugin (intro/outro/recap/preview). If a segment
   doesn't exist on the server the endpoint returns no data and the feature
   silently no-ops.
7. **Audio.** `AudioSettings` is an `@Observable` environment object that
   drives VLC media options via `vlcAudioOptions()` — passthrough,
   downmix-to-5.1, downmix-to-stereo, plus optional boost/normalization.
   Device capabilities are detected from `AVAudioSession`.

### Views

- tvOS focus effects live in `HyprTV/Extensions/View+TVFocus.swift`:
  `.tvCardStyle()`, `.tvScaleEffect(isFocused:)`, `.tvPosterEffect(isFocused:)`.
  Prefer these over rolling new scale/shadow modifiers.
- Layout constants (poster sizes, spacing, focus scale factor) live in
  `HyprTV/Utilities/Constants.swift`. Use them instead of hard-coding.
- The Home screen has a dynamic, focus-driven backdrop crossfade — see
  `HomeView.swift`. There's a 300 ms debounce on focus changes before loading
  a new backdrop so scrolling stays smooth.
- `ImageLoader` is an `actor` with a 3-tier cache (`NSCache` → disk →
  network) and in-flight deduplication. Always go through it; never hit
  `URLSession.shared` for images directly.

### Persistence

Three separate stores with different lifetimes:

| Store                | Contents                                        | Backed by       |
|----------------------|-------------------------------------------------|-----------------|
| `KeychainService`    | serverURL, accessToken, userId                  | Keychain        |
| `ServerStore`        | List of `SavedServer` (multi-server picker)     | UserDefaults    |
| `UserDefaultsStore`  | Language prefs, audio mode, subtitle flags, etc | UserDefaults    |
| `AudioSettings`      | Same audio keys, reads/writes UserDefaults      | UserDefaults    |
| `SubtitleStyle`      | Font, color, background, delay                  | UserDefaults    |

The device ID used in the `X-Emby-Authorization` header is persisted in
UserDefaults under `hypr_tv_device_id` (created on first launch).

### Logging

`HyprTV/Utilities/Logger+Extensions.swift` exposes categorised loggers:
`Logger.networking`, `.player`, `.ui`, `.auth`. Use these instead of `print`
or ad-hoc `Logger(subsystem:category:)` literals. Respect privacy: wrap
user/server-identifying data in `.public` only when it's already considered
public (item IDs) and prefer default (private) otherwise.

## Conventions

### Swift style

- Swift 5.9. Use modern concurrency (`async`/`await`, `Task`, `TaskGroup`) —
  do not introduce callbacks or Combine unless there's a concrete reason.
- Classes that back views are `@Observable final class`. Keep them thread-safe
  by routing mutations to the main actor when state comes from background work.
- Group members inside a type with `// MARK: -` section headers. Existing
  files follow this consistently; match the style when editing.
- Errors are domain-specific `LocalizedError` enums (`JellyfinError`,
  `PlayerViewModel.PlayerError`, `KeychainService.KeychainError`). Prefer
  adding cases to an existing enum over inventing new error types.
- Fire-and-forget server notifications (playback reporting, favourite,
  mark-played) should **not** surface errors to the user. Log and move on —
  never let them interrupt playback.

### File placement

- New DTOs → `HyprTV/Networking/DTOs/`.
- New API calls → add an `Endpoint` case and a `JellyfinClient` method; do
  not build URLs ad-hoc inside view models.
- New cross-screen state → `@Observable` model in `HyprTV/Models/` or a
  service in `HyprTV/Services/`.
- New SwiftUI views → put them under the feature folder that matches their
  screen (`Views/Home`, `Views/Detail`, etc.). Generic reusable bits go in
  `Views/Components/`.
- Don't add a unit-test target on a whim — coordinate first; none currently
  exist and the build config doesn't include one.

### Don'ts

- **Don't** use `ObservableObject` / `@Published` / `@StateObject` for new
  code. The project standardises on Observation (`@Observable`).
- **Don't** bypass `JellyfinClient` to talk to the server. All REST calls go
  through `Endpoint` + `JellyfinClient`.
- **Don't** touch `VLCMediaPlayer` outside `VLCPlayerWrapper`. The wrapper is
  the only place that understands the real-vs-stub split.
- **Don't** route `.player(itemId:)` through `NavigationStack` — use
  `PlayerLauncher`.
- **Don't** store credentials in UserDefaults. Use `KeychainService`.
- **Don't** add third-party dependencies without a strong reason. The project
  has zero Swift Package Manager or CocoaPods dependencies checked in and
  VLCKit is the only binary framework it ships with.

## Working on this repo as an agent

- **Branch**: develop on `claude/add-claude-documentation-BR3lJ` (or whatever
  branch the task spec provides). Create the branch locally if it does not
  exist. Never push to `main`/`master` directly.
- **Commits**: write descriptive commit messages in the existing style
  (`feat: …`, `fix: …`). Commit only when the user asks you to.
- **Scope**: stick to the task. Don't do drive-by refactors, don't add
  documentation comments to untouched code, and don't rewrite existing
  working screens.
- **Cross-platform builds**: remember that the Simulator build compiles
  against `VLCStub.swift`, so any change to the VLC wrapper must still
  compile under `#if !targetEnvironment(simulator)` and the stub branch.
- **When in doubt**: read the existing screen you're modifying end-to-end
  before editing. Most of the tricky behaviour (navigation, focus, playback
  lifecycle) only makes sense once you've seen how `RootView`, `AppRouter`,
  and `PlayerLauncher` interact.
