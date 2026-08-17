# Technical Specification: NativeHA (Native iOS Client for Home Assistant)

**Document Version:** 1.0.0  
**Target Platform:** iOS 17.0+ / iPadOS 17.0+  
**Language & UI:** Swift 5.10+ / Swift 6, SwiftUI (100% Native)  
**Primary Audience:** Autonomous Coding Agents & Software Engineers  

---

## 1. Executive Summary & Vision

### 1.1 Purpose
`NativeHA` is a lightweight, high-performance native iOS application designed to render Home Assistant dashboards natively using SwiftUI. While the official Home Assistant Companion app utilizes web views (`WKWebView`) to display Lovelace dashboards, `NativeHA` translates the Home Assistant dashboard schema—specifically modern **Sections-based dashboards**—into native SwiftUI view hierarchies, native controls, and hardware-accelerated animations.

### 1.2 Core Value Proposition
- **Fluid 120Hz Native Performance:** Eliminates webview stutter, scroll latency, and DOM repaint overhead.
- **Apple HIG Conformance:** Native iOS look-and-feel (haptics, materials, dynamic type, spring animations, native sheets/sliders) infused with Home Assistant's iconic design language.
- **Responsive Layout Engine:** Replicates Home Assistant's adaptive CSS grid section system natively across iPhone, iPad, Split View, and Stage Manager.
- **Low Memory & Battery Footprint:** Direct WebSocket subscription model without rendering web engine overhead.

### 1.3 Scope & Boundaries (Version 1.0)
| In Scope (v1.0) | Out of Scope (v1.0 / Future) |
| :--- | :--- |
| Server connection setup & URL validation | Dashboard YAML/UI editing (Read-only view) |
| Persistent authentication (OAuth2 & Long-Lived Token) | Non-section dashboards (Masonry, Panel, Sidebar) |
| Dashboard selector (filtering for section-based dashboards) | Location tracking / geofencing / background beacons |
| Native Section layout rendering (Adaptive columns) | Push notification action categories & triggers |
| V1 Core Cards: Tile, Heading, Button, Entities, Sensor, Gauge, Markdown, Badges | Custom Lovelace cards / HACS JS plugins |
| Real-time state synchronization via WebSocket API | Multi-server switching (Single active server in v1) |
| Native Entity interactions (Toggle, tap action, slider control) | Camera WebRTC streaming / complex video players |
| Light & Dark mode support with HA color tokens | Apple Watch / CarPlay / macOS targets |

---

## 2. System Architecture & Tech Stack

### 2.1 Technology Stack
- **Target OS:** iOS 17.0+ / iPadOS 17.0+
- **Architecture:** Clean Architecture + Unidirectional Data Flow (MVVM / Reducer-like State Observation)
- **Concurrency:** Swift Concurrency (`async`/`await`, `Actors`, `AsyncStream`)
- **State Management:** Swift Observation Framework (`@Observable`)
- **Networking:** Native `URLSessionWebSocketTask` (WebSocket) and `URLSession` (REST)
- **Security & Storage:** iOS Keychain (`Security.framework`) for tokens; `UserDefaults` for user preferences and server metadata
- **Icons:** Material Design Icons (MDI) to Apple SF Symbols mapping engine + bundled MDI font glyph fallback
- **Dependencies:** **Zero external third-party dependencies** (Pure Swift Package Manager architecture using Apple native frameworks)

### 2.2 High-Level Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Presentation Layer                            │
│                                                                        │
│  ┌───────────────────────┐  ┌──────────────────────────────────────┐  │
│  │   Navigation Layer    │  │       Dashboard View Engine          │  │
│  │ (DashboardSelector,   │  │   - SectionGridContainer             │  │
│  │  ServerConfigView)    │  │   - SectionCardView                  │  │
│  └──────────┬────────────┘  │   - CardRegistry (Tile, Button, etc.)│  │
│             │               └──────────────────┬───────────────────┘  │
└─────────────┼──────────────────────────────────┼──────────────────────┘
              │                                  │
┌─────────────▼──────────────────────────────────▼──────────────────────┐
│                            Domain Layer                                │
│                                                                        │
│  ┌────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │   EntityStoreActor     │  │       DashboardRepository            │  │
│  │  (Reactive Entity Dict │  │  - Parses Lovelace Config Schema     │  │
│  │   & State Updates)     │  │  - Filters "sections" type views     │  │
│  └──────────▲─────────────┘  └──────────────────▲───────────────────┘  │
└─────────────┼───────────────────────────────────┼──────────────────────┘
              │                                   │
┌─────────────┴───────────────────────────────────┴──────────────────────┐
│                         Infrastructure Layer                           │
│                                                                        │
│  ┌────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │  HAWebSocketClient     │  │          HAAuthManager               │  │
│  │  - Ping/Pong Heartbeat │  │  - OAuth2 Flow / LLAT                │  │
│  │  - Reconnect Backoff   │  │  - Keychain Storage                  │  │
│  │  - Command Dispatcher  │  │  - Token Refresh Pipeline            │  │
│  └────────────────────────┘  └──────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Connection & Authentication Specification

### 3.1 Server Connection Configuration
The application must support configuring a Home Assistant instance:
1. **Server URL Entry:**
   - User inputs URL (e.g., `https://homeassistant.local:8123` or `https://my-ha.duckdns.org`).
   - Normalization: Auto-strip trailing slashes, validate URL format (`http://` or `https://`).
   - Connectivity Probe: Sends `GET /api/discovery_info` or `GET /api/` to verify reachability.
2. **Local / Internal URL Support (Optional in settings):**
   - Ability to configure separate Internal and External URLs with automatic fallback or SSID matching.

### 3.2 Authentication Flows
The app supports two authentication mechanisms:

#### A. Standard Home Assistant OAuth2 Flow (Recommended)
1. **Authorization Request:**
   - Opens `ASWebAuthenticationSession` to:
     `{server_url}/auth/authorize?client_id={client_id}&redirect_uri={redirect_uri}&response_type=code`
   - Client ID: `https://home-assistant.io/iOS` or custom app bundle ID scheme `nativeha://auth-callback`.
2. **Token Exchange:**
   - `POST {server_url}/auth/token` with payload:
     ```json
     {
       "grant_type": "authorization_code",
       "code": "{authorization_code}",
       "client_id": "{client_id}"
     }
     ```
   - Response stores `access_token`, `refresh_token`, and `expires_in`.
3. **Token Refresh Mechanism:**
   - Automatically triggered 5 minutes before expiration or upon receiving WebSocket `auth_invalid`.
   - `POST {server_url}/auth/token` with `grant_type=refresh_token`.

#### B. Long-Lived Access Token (LLAT) Entry
- Direct input of user-generated Long-Lived Access Token for simplified local setups or development.

### 3.3 Secure Storage (Keychain)
Tokens must be securely stored in the iOS Keychain using `kSecClassGenericPassword`:
- Service: `com.nativeha.auth`
- Account: `ha_server_tokens_{server_id}`
- Stored data: Encrypted JSON containing `accessToken`, `refreshToken`, `tokenType`, `expiryDate`, `serverURL`.

---

## 4. Home Assistant API & WebSocket Protocol

### 4.1 WebSocket Connection Lifecycle
1. Connect to `ws://` or `wss://{server_host}:{port}/api/websocket`.
2. **Handshake Phase:**
   - Server sends: `{"type": "auth_required", "ha_version": "..."}`
   - Client replies: `{"type": "auth", "access_token": "{access_token}"}`
   - Server replies: `{"type": "auth_ok", "ha_version": "..."}` or `{"type": "auth_invalid", "message": "..."}`
3. **Keep-Alive Heartbeat:**
   - Client issues `{"id": <seq>, "type": "ping"}` every 30 seconds.
   - If no `pong` is received within 10 seconds, drop connection and trigger reconnect.
4. **Resilient Reconnection Policy:**
   - State Machine: `disconnected` ➔ `connecting` ➔ `authenticating` ➔ `connected` ➔ `reconnecting`.
   - Exponential backoff: Initial retry at 1s, doubling up to 30s max with 20% random jitter.
   - Network path monitoring via `NWPathMonitor` to instantly trigger reconnection when network transitions (e.g. Cellular to Wi-Fi).

### 4.2 Core WebSocket Commands & Message Formats

#### 1. Fetching Lovelace Dashboards List
- **Request:**
  ```json
  { "id": 1, "type": "lovelace/dashboards/list" }
  ```
- **Response Structure:**
  ```json
  {
    "id": 1,
    "type": "result",
    "success": true,
    "result": [
      {
        "id": "main_dashboard",
        "url_path": "lovelace",
        "title": "Home",
        "icon": "mdi:home",
        "show_in_sidebar": true,
        "require_admin": false
      },
      {
        "id": "tablet_view",
        "url_path": "tablet",
        "title": "Tablet Dashboard",
        "icon": "mdi:tablet",
        "show_in_sidebar": true,
        "require_admin": false
      }
    ]
  }
  ```

#### 2. Fetching Lovelace Dashboard Configuration
- **Request (Default Dashboard):**
  ```json
  { "id": 2, "type": "lovelace/config" }
  ```
- **Request (Custom Dashboard via `url_path`):**
  ```json
  { "id": 3, "type": "lovelace/config", "url_path": "tablet" }
  ```
- **Response Structure:**
  ```json
  {
    "id": 2,
    "type": "result",
    "success": true,
    "result": {
      "title": "My Home",
      "views": [
        {
          "title": "Living Room",
          "path": "living-room",
          "type": "sections",
          "max_columns": 3,
          "badges": [
            { "type": "entity", "entity": "sensor.outdoor_temperature" },
            { "type": "entity", "entity": "binary_sensor.front_door" }
          ],
          "sections": [
            {
              "title": "Lights & Climate",
              "cards": [
                {
                  "type": "heading",
                  "heading": "Lighting",
                  "heading_style": "title"
                },
                {
                  "type": "tile",
                  "entity": "light.living_room_ceiling",
                  "name": "Main Lights",
                  "icon": "mdi:ceiling-light",
                  "features": [
                    { "type": "light-brightness" }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  }
  ```

#### 3. Subscribing to Entity States (Compressed Stream)
- **Request:**
  ```json
  { "id": 4, "type": "subscribe_entities" }
  ```
- **Initial Event (Full State Dump):**
  ```json
  {
    "id": 4,
    "type": "event",
    "event": {
      "a": {
        "light.living_room_ceiling": {
          "s": "on",
          "a": {
            "friendly_name": "Living Room Ceiling",
            "brightness": 204,
            "supported_color_modes": ["brightness"]
          },
          "lc": 1700000000.0
        }
      }
    }
  }
  ```
- **Subsequent Event (Delta Updates):**
  ```json
  {
    "id": 4,
    "type": "event",
    "event": {
      "c": {
        "light.living_room_ceiling": {
          "+": {
            "s": "off"
          }
        }
      }
    }
  }
  ```

#### 4. Service Calls (Entity Interactions)
- **Request:**
  ```json
  {
    "id": 5,
    "type": "call_service",
    "domain": "light",
    "service": "toggle",
    "target": {
      "entity_id": "light.living_room_ceiling"
    }
  }
  ```

---

## 5. Home Assistant Data Models (Swift Codable Specs)

### 5.1 Dashboard Schema Models

```swift
struct LovelaceConfig: Codable, Sendable {
    let title: String?
    let views: [LovelaceView]
}

struct LovelaceView: Codable, Identifiable, Sendable {
    var id: String { path ?? title ?? UUID().uuidString }
    let title: String?
    let path: String?
    let icon: String?
    let type: String?             // e.g. "sections", "masonry", "sidebar"
    let maxColumns: Int?          // Custom column limit on wide screens (default: 4)
    let badges: [AnyCardConfig]?  // Array of badge configs
    let sections: [LovelaceSection]?
    
    var isSectionsType: Bool {
        type == "sections"
    }
    
    enum CodingKeys: String, CodingKey {
        case title, path, icon, type, badges, sections
        case maxColumns = "max_columns"
    }
}

struct LovelaceSection: Codable, Identifiable, Sendable {
    var id: String = UUID().uuidString
    let title: String?
    let icon: String?
    let columnSpan: Int?          // Default 1 column
    let cards: [AnyCardConfig]
    
    enum CodingKeys: String, CodingKey {
        case title, icon, cards
        case columnSpan = "column_span"
    }
}
```

### 5.2 Dynamic Polymorphic Card Model (`AnyCardConfig`)

```swift
struct AnyCardConfig: Codable, Identifiable, Sendable {
    let id: String
    let type: String
    let rawData: [String: AnyCodable]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawDict = try container.decode([String: AnyCodable].self)
        self.rawData = rawDict
        self.type = rawDict["type"]?.stringValue ?? "unknown"
        self.id = rawDict["id"]?.stringValue ?? UUID().uuidString
    }
    
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(rawData)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### 5.3 Entity State Model

```swift
struct HAEntityState: Identifiable, Sendable {
    let entityId: String
    var id: String { entityId }
    let state: String
    let attributes: [String: AnyCodable]
    let lastChanged: Date
    let lastUpdated: Date
    
    var domain: String {
        entityId.components(separatedBy: ".").first ?? ""
    }
    
    var friendlyName: String {
        attributes["friendly_name"]?.stringValue ?? entityId
    }
    
    var icon: String? {
        attributes["icon"]?.stringValue
    }
    
    var isOn: Bool {
        state == "on" || state == "open" || state == "home" || state == "active"
    }
    
    var brightnessPercentage: Double? {
        guard let b = attributes["brightness"]?.doubleValue else { return nil }
        return (b / 255.0) * 100.0
    }
}
```

---

## 6. Sections Layout & Responsive Grid Engine

The Home Assistant Sections layout organizes content in a hierarchical 2-level grid:
1. **View Level (Section Columns):** Multiple sections flow into adaptive columns.
2. **Section Level (Card Grid):** Cards inside each section occupy a 12-subcolumn or 4-subcolumn grid.

### 6.1 View-Level Breakpoint & Column Mathematics

The native layout must calculate the number of section columns based on available horizontal width:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Available Viewport Width (w)                       │
│                                                                         │
│   w < 600 pt  (iPhone Portrait, Slide Over)       ──►  1 Column         │
│   600 pt ≤ w < 1024 pt  (iPad Portrait, iPhone L) ──►  2 Columns        │
│   1024 pt ≤ w < 1440 pt  (iPad Landscape, Mac)    ──►  3 Columns        │
│   w ≥ 1440 pt  (Full iPad Pro 12.9", Pro Display) ──►  4 Columns (max)  │
└─────────────────────────────────────────────────────────────────────────┘
```

**Custom `max_columns` Override:** If `view.maxColumns` is specified in configuration, clamp the calculated columns to `min(calculatedColumns, view.maxColumns)`.

### 6.2 Layout Algorithm Implementation (SwiftUI)

```swift
struct SectionLayoutEngine {
    static let minSectionWidth: CGFloat = 340.0
    static let sectionSpacing: CGFloat = 16.0
    static let contentPadding: CGFloat = 16.0

    static func calculateColumnCount(for totalWidth: CGFloat, maxAllowed: Int? = nil) -> Int {
        let usableWidth = totalWidth - (contentPadding * 2)
        let possibleColumns = Int((usableWidth + sectionSpacing) / (minSectionWidth + sectionSpacing))
        let columns = max(1, possibleColumns)
        if let maxAllowed = maxAllowed {
            return min(columns, maxAllowed)
        }
        return columns
    }
    
    static func gridColumns(count: Int) -> [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: minSectionWidth), spacing: sectionSpacing, alignment: .top), count: count)
    }
}
```

### 6.3 Card Layout Inside Sections
Inside a `LovelaceSection`:
- Cards render vertically in a card stack.
- When `grid_options` (or `columns` / `rows`) are defined on cards:
  - Default cards (e.g. `TileCard`) default to half-width or full-width depending on type and grid options.
  - A 2-column or 4-column sub-grid inside the section handles side-by-side tiles.
- Cards maintain a uniform **corner radius of 16pt**, subtle borders/materials, and 12pt internal spacing.

---

## 7. Native Card Component Specifications (V1 Scope)

### 7.1 Card Registry & Factory Pattern
A centralized `CardRegistry` maps the YAML/JSON `type` string to a concrete SwiftUI view:

```swift
@MainActor
struct CardViewFactory {
    @ViewBuilder
    static func buildCard(config: AnyCardConfig, entityStore: EntityStore) -> some View {
        switch config.type {
        case "heading":
            HeadingCardView(config: try? config.decode(HeadingCardConfig.self))
        case "tile":
            TileCardView(config: try? config.decode(TileCardConfig.self), entityStore: entityStore)
        case "button":
            ButtonCardView(config: try? config.decode(ButtonCardConfig.self), entityStore: entityStore)
        case "entities":
            EntitiesCardView(config: try? config.decode(EntitiesCardConfig.self), entityStore: entityStore)
        case "sensor":
            SensorCardView(config: try? config.decode(SensorCardConfig.self), entityStore: entityStore)
        case "gauge":
            GaugeCardView(config: try? config.decode(GaugeCardConfig.self), entityStore: entityStore)
        case "markdown":
            MarkdownCardView(config: try? config.decode(MarkdownCardConfig.self))
        default:
            UnsupportedCardView(type: config.type, rawConfig: config.rawData)
        }
    }
}
```

---

### 7.2 Detailed Card Specifications

#### 1. Heading Card (`type: "heading"`)
- **Purpose:** Represents section headers, groupings, and titles with optional subtitle, icon, and badges.
- **Config:**
  - `heading`: String (Title text)
  - `heading_style`: String (`"title"`, `"subtitle"`, `"headline"`)
  - `icon`: String? (MDI icon)
  - `badges`: Array of inline badge objects
- **UI Spec:**
  - Typography: `.font(.title3.weight(.bold))` for title style; `.font(.headline)` for subtitle.
  - Padding: 8pt vertical, aligned to leading edge.

#### 2. Tile Card (`type: "tile"`)
- **Purpose:** Primary modern Home Assistant card representing an entity with state, icon, tap action, and interactive features.
- **Config:**
  - `entity`: String (e.g. `light.living_room`, `climate.thermostat`, `switch.fan`)
  - `name`: String? (Override friendly name)
  - `icon`: String? (Override icon)
  - `color`: String? (Custom accent color)
  - `tap_action`: ActionConfig? (`toggle`, `more-info`, `call-service`, `none`)
  - `features`: Array of features (`light-brightness`, `fan-speed`, `cover-open-close`)
- **UI Spec:**
  - Background: `Color(.secondarySystemGroupedBackground)` with `.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))`.
  - Left Icon: Circular background badge (40x40pt). When active, highlighted with entity domain color; when inactive, `.tertiarySystemFill`.
  - Center Text: Primary line = Name (`.font(.subheadline.weight(.semibold))`), Secondary line = State string / percentage (`.font(.caption).foregroundStyle(.secondary)`).
  - Features (e.g. Brightness Slider): Embedded native `Slider` or interactive custom scrub bar at the bottom of the card with spring animations and haptic feedback on adjustment.
  - Press Effect: `.scaleEffect(isPressed ? 0.97 : 1.0)` with `.snappy` spring animation.

#### 3. Button Card (`type: "button"`)
- **Purpose:** Large action tile displaying centered icon, state, and name.
- **Config:** `entity`, `name`, `icon`, `tap_action`, `show_state`, `show_name`.
- **UI Spec:**
  - Square or vertical rectangle.
  - Centered icon (32pt) with state-dependent glow or tint.
  - Single tap triggers service call (`toggle` or configured service) + `.impact(.medium)` haptic feedback.

#### 4. Entities Card (`type: "entities"`)
- **Purpose:** Compact vertical list of multiple entities.
- **Config:** `title`, `entities` (Array of entity IDs or row objects).
- **UI Spec:**
  - Renders as a grouped iOS list container (`.background(Color(.secondarySystemGroupedBackground))`).
  - Each row contains: Left Icon, Title, Secondary text/State, and Right-hand control (Native `Toggle` for switches/lights, chevron for info, or text state).
  - Subtle 0.5pt dividers between rows matching standard iOS grouped list separators.

#### 5. Sensor Card (`type: "sensor"`) & Gauge Card (`type: "gauge"`)
- **Sensor:** Displays primary measurement value, unit of measurement, name, icon, and optional mini sparkline graph.
- **Gauge:** Displays value inside a native curved gauge arc (built using SwiftUI `Gauge` view or custom `ArcShape`), colored according to threshold severity ranges (`green`, `yellow`, `red`).

#### 6. Markdown Card (`type: "markdown"`)
- **Purpose:** Formatted text block.
- **Config:** `content` (Markdown string with basic template stripping).
- **UI Spec:** Rendered via native SwiftUI `Text(LocalizedStringKey(content))` supporting bold, italic, lists, and links.

#### 7. Badges (View Header Level & Section Level)
- **Config:** `type: "entity"`, `entity: "sensor.temp"`, `icon`, `color`.
- **UI Spec:**
  - Rendered in a horizontal scrolling or wrapping pill shelf at the top of the view.
  - Compact pill shape: Height 32pt, rounded capsule with icon + state string.

#### 8. Unsupported Card Fallback (`UnsupportedCardView`)
- **Purpose:** Graceful fallback for custom or unhandled card types.
- **UI Spec:**
  - Dashed outline container with warning icon (`exclamationmark.triangle`).
  - Displays `"Unsupported Card: {type}"` with expandable disclosure group showing formatted JSON payload for debugging.
  - **Must never crash the app or break the surrounding grid.**

---

## 8. Design System, Apple HIG & Home Assistant Theming

### 8.1 Color Palette & Token System
The app uses semantic colors that dynamically adapt to iOS Light & Dark modes while respecting Home Assistant branding:

```swift
extension Color {
    // Brand Tokens
    static let haBlue = Color(hex: "#03A9F4")
    static let haBlueDark = Color(hex: "#0288D1")
    
    // Domain State Colors
    static let haLightActive = Color(hex: "#FDD835")     // Warm Amber/Yellow
    static let haSwitchActive = Color(hex: "#00E676")    // Green
    static let haClimateHeating = Color(hex: "#FF5722") // Orange-Red
    static let haClimateCooling = Color(hex: "#2196F3") // Cold Blue
    static let haUnavailable = Color(hex: "#9E9E9E")    // Muted Gray
    
    // Semantic Surface & Background Tokens
    static let haBackground = Color(uiColor: .systemGroupedBackground)
    static let haCardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let haCardBackgroundElevated = Color(uiColor: .tertiarySystemGroupedBackground)
}
```

### 8.2 Icon Mapping Engine (MDI to SF Symbols)
Home Assistant entities use Material Design Icons (`mdi:lightbulb`, `mdi:fan`, `mdi:door-closed`). The app includes a deterministic lookup dictionary mapping common MDI identifiers to Apple SF Symbols:

| MDI Name | SF Symbol Equivalent | Active Variant |
| :--- | :--- | :--- |
| `mdi:lightbulb` | `lightbulb` | `lightbulb.fill` |
| `mdi:lightbulb-group` | `lightbulb.2` | `lightbulb.2.fill` |
| `mdi:power` / `mdi:toggle-switch` | `power` | `power.circle.fill` |
| `mdi:fan` | `fan` | `fan.fill` |
| `mdi:thermometer` | `thermometer.medium` | `thermometer.sun.fill` |
| `mdi:motion-sensor` | `sensor.motion` | `sensor.motion.fill` |
| `mdi:door-closed` | `door.left.hand.closed` | `door.left.hand.open` |
| `mdi:window-closed` | `window.vertical.closed`| `window.vertical.open` |
| `mdi:home` | `house` | `house.fill` |
| `mdi:account` | `person` | `person.fill` |
| *Unknown/Unmapped* | `circle.grid.2x2` | `circle.grid.2x2.fill` |

*Note: The engine must gracefully return fallback symbols without crashing.*

### 8.3 Typography & Dynamic Type
- View Titles: `.largeTitle.weight(.bold)`
- Section Headers: `.title3.weight(.bold)`
- Card Titles: `.subheadline.weight(.semibold)`
- Secondary State/Values: `.caption` (tabular numbers enabled for numeric sensor values via `.monospacedDigit()`).
- All text components must scale seamlessly with iOS Dynamic Type settings.

---

## 9. App User Experience & Navigation Flows

```
┌────────────────────────────────────────────────────────────────────────┐
│                          Navigation Structure                          │
└────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                      ┌───────────────────────────┐
                      │    Server Setup View      │  (If not configured/
                      │ (URL entry, Auth Login)   │   logged out)
                      └─────────────┬─────────────┘
                                    │ (On success)
                                    ▼
                      ┌───────────────────────────┐
                      │    Main Dashboard Host    │
                      └─────────────┬─────────────┘
                                    │
        ┌───────────────────────────┴───────────────────────────┐
        ▼ (iPhone)                                              ▼ (iPad / Wide)
┌──────────────────────────────┐              ┌─────────────────────────────────┐
│ NavigationStack              │              │ NavigationSplitView             │
│ - Top Bar: Dashboard Picker  │              │ - Sidebar: Dashboard & View list│
│   Menu & View Tab Bar        │              │ - Detail: Active Section View   │
│ - Content: Section Grid View │              │ - Top Bar: Badges shelf         │
│ - Sheet: Entity More Info    │              │ - Sheet: Entity More Info       │
└──────────────────────────────┘              └─────────────────────────────────┘
```

### 9.1 Dashboard Selection Behavior
- When the WebSocket connects, it queries `lovelace/dashboards/list` and the default `lovelace/config`.
- It inspects each dashboard's views:
  - If a dashboard contains **at least one view with `type == "sections"`**, it is included in the available dashboard list.
  - Non-section dashboards and non-section views are filtered out (or clearly flagged as non-section views).
- The user can select their active dashboard via:
  - **iPhone:** A navigation title dropdown menu (`Picker` / `Menu`) or top toolbar button.
  - **iPad:** A sidebar list in `NavigationSplitView`.
- The user's last selected dashboard ID and view path are persisted in `UserDefaults` and restored upon subsequent launches.

---

## 10. Project Directory & File Structure

The project will follow a clean, modular structure organized by architectural boundaries:

```
NativeHA/
├── App/
│   ├── NativeHAApp.swift                 # Main App Entrypoint
│   └── AppState.swift                    # Root application state & router
│
├── Core/
│   ├── Networking/
│   │   ├── HAWebSocketClient.swift       # URLSessionWebSocketTask manager
│   │   ├── HAWebSocketMessage.swift      # Protocol request/response frames
│   │   ├── HAConnectionState.swift       # State machine enum & stream
│   │   └── HARestClient.swift            # REST endpoints (auth, token exchange)
│   │
│   ├── Auth/
│   │   ├── HAAuthManager.swift           # OAuth2 / LLAT lifecycle & refresh
│   │   ├── KeychainStorage.swift         # Secure token store wrapper
│   │   └── ServerConfig.swift            # Server URLs & configuration model
│   │
│   ├── State/
│   │   ├── EntityStore.swift             # @Observable central entity dictionary
│   │   └── DashboardRepository.swift     # Fetches & parses Lovelace schemas
│   │
│   └── Utilities/
│       ├── IconMapper.swift              # MDI -> SF Symbols resolver
│       ├── AnyCodable.swift              # Type-erased JSON decoder helper
│       └── Color+Extensions.swift        # HA theme palette & color hex parser
│
├── Models/
│   ├── HAEntity.swift                    # Entity state & attribute models
│   ├── LovelaceConfig.swift              # View, Section, and Badges schema
│   └── CardConfig.swift                  # Concrete Card config models (Tile, etc.)
│
├── Layout/
│   ├── SectionLayoutEngine.swift         # Grid math & breakpoint calculator
│   └── AdaptiveGridContainer.swift       # SwiftUI multi-column section container
│
├── Views/
│   ├── Setup/
│   │   ├── ServerSetupView.swift         # URL entry & connectivity tester
│   │   └── OAuthLoginView.swift          # ASWebAuthenticationSession wrapper
│   │
│   ├── Dashboard/
│   │   ├── DashboardHostView.swift       # Main container (iPhone/iPad adaptive)
│   │   ├── DashboardSelectorMenu.swift   # Switcher for section dashboards
│   │   ├── SectionViewContainer.swift    # View header, badges, and section grid
│   │   └── SectionContainerView.swift    # Individual section box & card stack
│   │
│   ├── Cards/
│   │   ├── CardViewFactory.swift         # Polymorphic card dispatcher
│   │   ├── HeadingCardView.swift         # Section heading card
│   │   ├── TileCardView.swift            # Interactive tile card + slider
│   │   ├── ButtonCardView.swift          # Action button card
│   │   ├── EntitiesCardView.swift        # Multi-row entities card
│   │   ├── SensorCardView.swift          # Sensor & sparkline card
│   │   ├── GaugeCardView.swift           # Native circular gauge card
│   │   ├── MarkdownCardView.swift        # Formatted markdown card
│   │   ├── BadgePillView.swift           # Header badge pill
│   │   └── UnsupportedCardView.swift     # Graceful fallback card
│   │
│   └── Modals/
│       ├── EntityMoreInfoSheet.swift     # Entity details, history, & controls
│       └── SettingsSheet.swift           # Server info, disconnect, debug logs
│
└── Resources/
    ├── Assets.xcassets                   # App icons, accent colors
    └── Preview Content/
        └── MockData.swift                # Mock JSON payloads for Xcode Previews
```

---

## 11. Implementation Phases for Coding Agents

Coding agents implementing this project should proceed in the following ordered phases:

### Phase 1: Foundation & Data Infrastructure
1. Implement `ServerConfig`, `KeychainStorage`, and `HAAuthManager` (supporting LLAT and OAuth2).
2. Implement `HAWebSocketClient` with JSON message framing, ping/pong heartbeat, and reconnection state machine.
3. Implement `EntityStore` to handle `subscribe_entities` initial payloads and compressed delta updates (`+` / `-`).
4. Unit tests: WebSocket frame serialization, Keychain storage mock, Entity delta patching.

### Phase 2: Schema Parsing & Repository
1. Implement `LovelaceConfig`, `LovelaceView`, `LovelaceSection`, and polymorphic `AnyCardConfig` coders.
2. Implement `DashboardRepository` to fetch dashboard lists via `lovelace/dashboards/list` and configs via `lovelace/config`.
3. Filter views to only expose `type: "sections"`.
4. Unit tests: Parse realistic sample Home Assistant Lovelace JSON fixtures.

### Phase 3: Layout Engine & UI Scaffolding
1. Implement `SectionLayoutEngine` and `AdaptiveGridContainer` using SwiftUI `LazyVGrid` and `GeometryReader`.
2. Implement responsive column adjustments (1 col on iPhone, 2-4 cols on iPad).
3. Implement `DashboardHostView` with `NavigationStack` (iPhone) and `NavigationSplitView` (iPad).
4. Implement `DashboardSelectorMenu` and View tab selection.

### Phase 4: Core Card Implementations
1. Build `HeadingCardView` and `BadgePillView`.
2. Build `TileCardView` with interactive state feedback, icon tinting, and brightness feature slider.
3. Build `ButtonCardView`, `EntitiesCardView`, `SensorCardView`, `GaugeCardView`, and `MarkdownCardView`.
4. Build `UnsupportedCardView` fallback.
5. Connect entity actions (`toggle`, slider drag) to `HAWebSocketClient.callService()`.

### Phase 5: Polish, HIG, & Error Handling
1. Implement `IconMapper` for MDI to SF Symbols.
2. Add haptic feedback (`UIImpactFeedbackGenerator`) on taps and toggles.
3. Implement network disconnection banners and auto-reconnect toasts.
4. Verify Dark Mode and Dynamic Type rendering.

---

## 12. Verification & Acceptance Criteria

| ID | Requirement | Verification Method |
| :--- | :--- | :--- |
| **AC-01** | Server Connection | Enter valid and invalid HA URLs; verify proper validation, error alerts, and connection establishment. |
| **AC-02** | Persistent Auth | Log in via OAuth or LLAT; restart the app and verify the user remains authenticated without re-prompting. |
| **AC-03** | Dashboard Filtering | Connect to an instance with mixed dashboards (Masonry, Section); verify only Section dashboards/views appear in the selector. |
| **AC-04** | Responsive Layout | Test on iPhone SE (1 column), iPhone 15 Pro Max (1 column), iPad Air (2 columns), iPad Pro 12.9" Landscape (3-4 columns). Verify fluid reflow on rotation and Stage Manager resizing. |
| **AC-05** | Real-time Entity Sync | Change a light's state in HA Web UI; verify the native tile card updates state, icon, and brightness within <200ms without manual refresh. |
| **AC-06** | Entity Interaction | Tap a tile/button in NativeHA; verify the physical device or HA state toggles immediately and plays appropriate haptic feedback. |
| **AC-07** | Graceful Degradation | Load a dashboard with an unsupported custom card (e.g. `type: "custom:button-card"`); verify `UnsupportedCardView` renders without crashing the app. |
| **AC-08** | HIG & Visual Design | Verify native iOS materials, rounded corners (16pt), dynamic type scaling, and seamless light/dark mode transitions. |
