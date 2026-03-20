# Hypr TV

Free, open-source tvOS media player for Jellyfin servers. A modern replacement for Infuse, Swiftfin, and the official Jellyfin client on Apple TV.

## Features

- **VLCKit-based playback** -- plays virtually any format including MKV, MP4, AVI, HEVC, H.264, and more
- **Full audio codec support** -- DTS, DTS-HD Master Audio, Dolby Digital, Dolby TrueHD, AAC, FLAC, and others
- **Jellyfin server discovery** -- automatic local network discovery via Bonjour and manual server entry
- **Library browsing** -- browse movies, TV shows, music, and other media organized by your Jellyfin server
- **Multi-track audio and subtitle support** -- switch audio tracks and subtitles during playback
- **Resume playback** -- syncs watch progress with your Jellyfin server
- **Native tvOS interface** -- built with SwiftUI for a fluid, focus-driven experience on Apple TV

## Architecture

Hypr TV is built with modern Apple development practices:

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Architecture Pattern**: MVVM (Model-View-ViewModel)
- **Concurrency**: Swift async/await and structured concurrency
- **Playback Engine**: VLCKit
- **Networking**: URLSession with Jellyfin REST API

## Requirements

- Xcode 15 or later
- tvOS 17.0+ deployment target
- Apple TV (4th generation or later)
- A Jellyfin server on your local network or accessible via URL

## Building

1. Clone the repository:
   ```
   git clone https://github.com/hypr-tv/hypr-tv-os.git
   ```
2. Open `HyprTV.xcodeproj` in Xcode.
3. Select an Apple TV simulator or a connected Apple TV device.
4. Build and run (Cmd+R).

## Project Structure

```
HyprTV/
├── HyprTVApp.swift            # App entry point
├── Info.plist                  # App configuration
├── Assets.xcassets/            # Asset catalogs (icons, colors)
├── Preview Content/            # SwiftUI preview assets
├── Navigation/                 # App router and root navigation
│   ├── AppRouter.swift
│   └── RootView.swift
├── Models/                     # Data transfer objects and domain models
├── Networking/                 # Jellyfin API client and request handling
├── Services/                   # Server discovery, authentication, playback reporting
├── ViewModels/                 # Observable view models for each screen
├── Views/                      # SwiftUI views
│   ├── ServerConnection/       # Server setup and login
│   ├── Home/                   # Home screen with continue watching, recent items
│   ├── Library/                # Library browsing and filtering
│   ├── MediaDetail/            # Item detail pages (movie, episode, series)
│   ├── Search/                 # Global search
│   └── Settings/               # App settings
└── Player/                     # VLCKit integration and playback controls
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
