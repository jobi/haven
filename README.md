# Haven: Native iOS Client for Home Assistant

A high-performance, 100% native iOS / iPadOS client for [Home Assistant](https://www.home-assistant.io) built specifically to render modern **Section-based dashboards** using pure SwiftUI.

---

## Highlights

- **100% Native SwiftUI:** Replaces heavy webviews with native views running at 120Hz ProMotion with low memory footprint (~30MB RAM).
- **Responsive Section Grid Engine:** Replicates Home Assistant's adaptive multi-column grid layout across iPhone, iPad (Portrait/Landscape), Split View, and Stage Manager.
- **Real-Time State Synchronization:** Direct WebSocket connection using Home Assistant's compressed `subscribe_entities` stream for sub-millisecond updates.
- **Zero Third-Party Dependencies:** Built entirely with standard Apple SDK frameworks (`SwiftUI`, `URLSession`, `Observation`, `Security`, `Charts`).
- **Apple HIG + Home Assistant Styling:** Native materials, haptics, spring animations, and dark/light modes infused with Home Assistant's design system.
- **Persistent Auth:** Supports OAuth2 (`ASWebAuthenticationSession`) and Long-Lived Access Tokens stored securely in the iOS Keychain.
- **Built-in Demo Smart Home:** Full offline simulation sandbox for evaluation, testing, and screenshots without needing a live server.

---

## Supported Core Cards (v1.0)

| Card Type | Description |
| :--- | :--- |
| **Tile Card (`tile`)** | Full interactive state, domain-colored icon badge, entity details, tap actions, and brightness slider scrubbers. |
| **Heading Card (`heading`)** | Section titles, subheadings, icons, and inline badge pills. |
| **Button Card (`button`)** | Direct action buttons with state glow and haptic feedback. |
| **Entities Card (`entities`)** | iOS grouped list container with native `Toggle` controls. |
| **Sensor Card (`sensor`)** | Formatted telemetry data with units and tabular numeric typography. |
| **Gauge Card (`gauge`)** | Circular arc gauges with green/yellow/red severity threshold coloring. |
| **Markdown Card (`markdown`)** | Formatted rich markdown content. |
| **Badges (`badge`)** | Top-level view badge shelf with compact status pills. |
| **Picture Entity (`picture-entity`)** | Live camera video streams with WebRTC/HLS/snapshot capabilities. |
| **Unsupported Fallback** | Graceful fallback container displaying card type and raw JSON for custom HACS cards without crashing. |

---

## Architecture Overview

```
Haven/
├── Package.swift                     # Swift Package configuration
├── Sources/
│   ├── NativeHACore/                 # Core Library Target
│   │   ├── Models/                   # Lovelace schema, Entity state, AnyCodable
│   │   ├── Networking/               # Actor-isolated WebSocket client, REST client
│   │   ├── Auth/                     # KeychainStorage, ServerConfig, HAAuthManager
│   │   ├── State/                    # EntityStore, DashboardRepository
│   │   ├── Layout/                   # SectionLayoutEngine, AdaptiveGridContainer
│   │   ├── Demo/                     # Simulated Smart Home backend and entities
│   │   ├── Utilities/                # IconMapper (MDI -> SF Symbols), Color+HA
│   │   └── Views/                    # SwiftUI Card components, Dashboard layouts, Setup modals
│   └── NativeHAApp/                  # App Target & @main entrypoint
└── Tests/
    └── NativeHATests/                # Comprehensive unit test suite
```

---

## Building and Running

### Command Line (Swift PM)
```bash
# Build the project
swift build

# Run all unit tests
swift test
```

### Xcode
1. Open the project in Xcode (`NativeHA.xcodeproj` or open the folder directly).
2. Select the `Haven` target and an iOS simulator or connected iPhone/iPad.
3. Press `Cmd + R` to build and run.

---

## Documentation
- [SPEC.md](SPEC.md): Full technical specification document.
- [FEASIBILITY_STUDY.md](FEASIBILITY_STUDY.md): In-depth API, UI, and performance feasibility study.
- [docs/CAMERA_STREAMING.md](docs/CAMERA_STREAMING.md): Technical deep-dive on WebRTC / HLS video streaming.
- [docs/APP_STORE_SUBMISSION.md](docs/APP_STORE_SUBMISSION.md): Complete App Store submission and metadata guide.
- [docs/PRIVACY_POLICY.md](docs/PRIVACY_POLICY.md): Privacy policy statement.

---

## License

Haven is open-source software licensed under the [Apache License, Version 2.0](LICENSE).
Copyright © 2026 Johan Bilien.
