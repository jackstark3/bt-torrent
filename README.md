# BT Torrent Searcher

[中文版 README](README.zh-CN.md)

An Android torrent search & download app built with Flutter. Search torrents from multiple sources, download via a native BitTorrent engine, and play downloaded videos locally — all on-device, no backend server required.

> ⚠️ **Legal notice**: This project is for learning and personal use only. Please respect copyright laws and torrent-site terms of service in your region.

## Features

- **Multi-source search** — aggregates results in parallel from 1337x (via 1377x mirror), The Pirate Bay (via mirror), SolidTorrents, TorrentGalaxy, and any Torznab indexer (Jackett / Prowlarr)
- **Search experience** — incremental result loading, category & sort filters, search history autocomplete, offline cache fallback, per-source health check & enable/disable
- **Native BT engine** — libtorrent4j (libtorrent 2.x) through a Pigeon bridge; DHT/LSD enabled, magnet metadata fetch, real-time progress push
- **Background downloads** — foreground service keeps downloads running when the app is backgrounded
- **Task persistence** — download tasks survive app restarts; incomplete tasks resume automatically
- **File export** — completed files are automatically exported to the public `Download` folder
- **Local video playback** — play completed videos with a full-screen player (play/pause, seek bar)
- **Network proxy support** — configure an HTTP proxy in Settings for restricted networks
- **Torznab integration** — point the app at your own Jackett / Prowlarr instance

## Tech Stack

| Layer | Technology |
|---|---|
| UI / Logic | Flutter (Dart) + Riverpod + go_router |
| Native engine | libtorrent4j 2.1.0-36 |
| Bridge | Pigeon (type-safe platform channels) |
| Networking | dio + HTML/XML parsing |
| Storage | SharedPreferences + JSON files |
| Player | video_player (Media3/ExoPlayer) |
| Background | Android foreground service |

## Build

Requirements: Flutter 3.x, Android SDK, JDK 17.

```bash
flutter pub get
flutter build apk --debug   # debug APK
flutter build apk --release # release APK
```

Notes for mainland-China networks:

- Gradle distribution downloads use a Tencent mirror in `android/gradle/wrapper/gradle-wrapper.properties`.
- Maven repositories are mirrored via Aliyun in `android/settings.gradle.kts` and `android/build.gradle.kts`.
- If `C:` is low on disk space, point Gradle caches elsewhere:

```powershell
$env:GRADLE_USER_HOME = "D:\gradle_home"
$env:TMP = "D:\tmp"; $env:TEMP = "D:\tmp"
flutter build apk --debug
```

The debug APK includes native libs for 3 ABIs (~200 MB). For release, consider per-ABI splits to shrink the size.

## Usage

1. **Search** — enter a keyword (or paste a magnet link). Results stream in from each source as they arrive.
2. **Download** — tap the download button on a result. The engine fetches metadata, then downloads with real-time progress.
3. **Play** — once complete, open the task detail and tap **Play**. The file is also exported to your phone's `Download` folder.
4. **Settings** — enable/disable search sources, configure a proxy, or set up a Torznab indexer.

## Project Structure

```
lib/
├── core/        # models, utilities, constants
├── domain/      # repository interfaces & use cases
├── data/        # repositories, local storage, search providers
├── engine/      # Dart-side BT engine facade + Pigeon bridge
├── features/    # search / download / player / settings screens
└── providers/   # Riverpod providers
android/
└── app/src/main/kotlin/com/bt/
    ├── engine/  # libtorrent4j session & torrent handle wrapper
    ├── bridge/  # Pigeon API implementation
    └── service/ # foreground download service
pigeons/         # Pigeon interface definitions
```

## Roadmap

- [x] Multi-source search
- [x] Native download engine
- [x] Local playback of completed files
- [ ] Progressive streaming (watch while downloading)
- [ ] DHT-based decentralized search
- [ ] Release build with ABI splits

## Disclaimer

This software is provided for educational purposes. Users are solely responsible for ensuring their usage complies with applicable laws and regulations.
