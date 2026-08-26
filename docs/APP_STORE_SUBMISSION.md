# Haven - App Store Submission Guide

This guide contains everything required to configure, list, and submit **Haven** to the Apple App Store.

---

## 1. App Store Connect Metadata

### General Information
- **App Name**: `Haven - Home Assistant Client` (or `Haven`)
- **Subtitle**: `Fast, native Home Assistant app` (max 30 characters)
- **Bundle ID**: `org.bilien.haven`
- **SKU**: `haven-ios-client`
- **Primary Category**: `Utilities`
- **Secondary Category**: `Lifestyle`
- **Age Rating**: `4+` (No objectionable content, no user-generated public content)
- **Pricing**: `Free` (Tier 0)

### URLs Required by Apple
- **Privacy Policy URL**: A publicly accessible URL stating privacy practices (e.g. `https://github.com/jobi/haven/blob/main/docs/PRIVACY_POLICY.md` or a GitHub Pages link).
- **Support URL**: `https://github.com/jobi/haven/issues` (or personal support webpage).
- **Marketing URL** *(Optional)*: `https://github.com/jobi/haven`

---

## 2. Store Listing Copy

### Promotional Text (max 170 chars)
> Fast, privacy-first, and native Home Assistant client for iOS. Live WebRTC camera streaming, real-time Lovelace dashboards, and multi-server support.

### Keywords (max 100 chars, comma-separated)
```
home assistant,smart home,automation,hass,lovelace,webrtc,camera,dashboard,iot,lights,climate,nest
```

### Full Description
```
Haven is a fast, beautifully designed, and privacy-focused native iOS client for Home Assistant. Built from the ground up in Swift and SwiftUI, Haven connects directly to your Home Assistant instances with zero middleman servers.

KEY FEATURES:
• Native Speed & Polish: Fluid SwiftUI animations, adaptive responsive layouts, and modern iOS typography.
• Live WebRTC & HLS Camera Streaming: Zero-latency camera feeds for Google Nest, go2rtc, and RTSP cameras with picture-in-picture and full-screen controls.
• Real-time Lovelace Dashboards: Full support for custom Lovelace cards, tile cards, entity grids, climate gauges, and media players with instant WebSocket synchronization.
• Multi-Server Management: Connect to multiple Home Assistant servers simultaneously and switch seamlessly.
• Quick Actions & Deep Linking: Control favorite entities and access server dashboards directly from the Home Screen.
• 100% Private & Local: No tracking, no analytics, no third-party telemetry. All credentials stay securely stored in your device's Apple Keychain.

REQUIREMENTS:
• An active Home Assistant instance (Core, Supervised, Container, or OS).
• Works over local Wi-Fi, Tailscale, WireGuard, Nabu Casa (Home Assistant Cloud), or reverse proxies.
```

---

## 3. App Privacy Nutrition Label (App Store Connect)

When completing the **App Privacy** questionnaire in App Store Connect:

1. **Do you collect data from this app?**
   - Select **No, we do not collect data from this app**.
2. **Third-Party SDKs / Analytics**:
   - None (Haven contains no third-party tracking, analytics, or advertising SDKs).
3. **Data Storage**:
   - All connection tokens and passwords are kept exclusively on the user's physical device in the Apple Keychain.

---

## 4. App Review Information & Rejection Response (Resolution Center Copy)

When submitting or replying to Apple App Review in the **Resolution Center** (or entering info into the **Notes** field in App Store Connect), copy and paste the following complete responses:

---

### App Store Review Resolution Center Reply (Copy & Paste)

```text
Dear Apple App Review Team,

Thank you for your review and guidance. Below are the detailed answers to each of the 7 requested items regarding Haven (org.bilien.haven), along with instructions for testing the app:

--------------------------------------------------------------------------------
1. SCREEN RECORDING DEMONSTRATING FUNCTIONALITY
--------------------------------------------------------------------------------
A screen recording captured on a physical iPhone running iOS is attached to this submission. The recording demonstrates:
• Launching the app on a fresh install.
• Accessing the app immediately via the built-in "Demo Smart Home" (no server/hardware required).
• Interacting with core smart home controls: toggling lights, switches, locks, and appliances.
• Adjusting light brightness, color temperature (Kelvin), and RGB color palettes.
• Viewing 24-hour interactive historical sensor charts (temperature/humidity).
• Viewing live security camera feeds with real-time HUD overlays and controls.
• Accessing Settings, multi-server management, and connection options.

Regarding specific flows:
• Account registration / login: Haven does not operate a proprietary user account system. It connects directly to the user's self-hosted Home Assistant server via standard OAuth2 / Long-Lived Access Tokens, or runs entirely offline in Demo Mode.
• Paid content / In-App Purchases: None. The app is completely free with no paywalled content, subscriptions, or IAPs.
• User-generated content / moderation: None. The app is a local controller utility for personal smart home hardware.
• Sensitive device permissions: None requested (no camera, microphone, contacts, location, or App Tracking Transparency required).

--------------------------------------------------------------------------------
2. TESTED DEVICE MODELS & OPERATING SYSTEMS
--------------------------------------------------------------------------------
The app was extensively tested on the following physical devices and simulators before submission:
• Physical Device: iPhone 16 Pro (iOS 18 / iOS 26 Darwin runtime)
• Simulators:
  - iPhone 16 Pro, iPhone 17 Pro, iPhone SE (3rd Gen) (iOS 17.0 - 26.0)
  - iPad Pro 13-inch (M4), iPad Air 11-inch (M3) (iPadOS 17.0 - 26.0)

--------------------------------------------------------------------------------
3. APP FUNCTIONS, TARGET AUDIENCE, AND PROBLEM SOLVED
--------------------------------------------------------------------------------
• Target Audience: Homeowners, IoT enthusiasts, and users of the open-source Home Assistant home automation ecosystem.
• Problem Solved: Standard mobile web interfaces for Home Assistant can suffer from higher latency, slower render performance, and higher battery consumption.
• Value Provided: Haven provides a 100% native, ultra-fast SwiftUI client that communicates directly with Home Assistant instances over WebSocket and REST APIs. It offers instant sub-second response times, fluid native gesture controls, live WebRTC camera streaming, multi-server management, and responsive layouts for both iPhone and iPad with zero cloud middlemen or data collection.

--------------------------------------------------------------------------------
4. SETUP & ACCESS INSTRUCTIONS (EASY TESTING - NO SERVER REQUIRED)
--------------------------------------------------------------------------------
The app includes a built-in "Demo Smart Home" sandbox specifically engineered for Apple Reviewers to exercise all features without needing physical smart home hardware or a self-hosted server:

1. Launch Haven on the device.
2. On the initial screen, tap:
   "Explore Demo Smart Home (No Server Required)"
3. The app will immediately load an interactive smart home with 30+ simulated entities across 3 dashboard views:
   • Home Overview: Tap tiles to toggle lights, fans, espresso machine, blinds, and locks.
   • Light & Entity Controls: Tap "Living Room Ceiling" to open detailed controls (brightness slider, color temperature, color presets).
   • Sensor History Charts: Tap "Living Room Temperature" to view the 24-hour interactive history graph and statistics.
   • Security & Live Cameras: Tap the "Security" tab to view real-time live camera streams with motion detection bounding boxes.
   • Multi-Server Management: Tap the Settings gear icon in the top toolbar to view server switching and configuration.

(Optional Live Server Testing): Reviewers wishing to test with a physical server can tap Settings -> "Add Another Server" and enter any standard Home Assistant URL with local or OAuth2 credentials.

--------------------------------------------------------------------------------
5. EXTERNAL SERVICES, TOOLS, AND PLATFORMS
--------------------------------------------------------------------------------
• Home Assistant WebSocket & REST API: Standard open-source communication protocol (/api/websocket) running directly on the user's private server.
• WebRTC / RTSP Streaming: Direct peer-to-peer or server-direct video streaming for local camera entities.
• External Third-Party Cloud Services / Trackers: NONE. Haven uses no third-party backend servers, no analytics/telemetry SDKs, no advertising frameworks, and no payment processors. All network communication is strictly peer-to-server between the user's iOS device and their private Home Assistant instance.

--------------------------------------------------------------------------------
6. REGIONAL DIFFERENCES & GLOBAL AVAILABILITY
--------------------------------------------------------------------------------
Haven functions consistently across all geographic regions worldwide without regional restrictions, geofencing, or localized feature limitations. Temperature units (°C/°F), dates, and time formats automatically adapt to the user's device locale and server configuration.

--------------------------------------------------------------------------------
7. REGULATORY & THIRD-PARTY MATERIAL DISCLOSURE
--------------------------------------------------------------------------------
• Regulated Industries: Haven does not operate in any regulated industry (such as banking, healthcare, gambling, or pharmaceuticals).
• Third-Party Material: Haven is an independent open-source client (Apache License 2.0) for the open-source Home Assistant platform. All bundled iconography is from Material Design Icons (licensed under Apache 2.0 / Pictogrammers Free License). No proprietary or protected third-party assets are used without authorization.
```

---

## 5. End-to-End Submission Walkthrough

### Step 1: Register App ID in Apple Developer Portal
1. Go to [Apple Developer Portal - Identifiers](https://developer.apple.com/account/resources/identifiers/list).
2. Click **+** to add an **App ID**.
3. Select **App** and enter:
   - **Description**: `Haven Home Assistant Client`
   - **Bundle ID**: `org.bilien.haven` (Explicit)
4. Click **Continue** $\rightarrow$ **Register**.

### Step 2: Create App in App Store Connect
1. Go to [App Store Connect - Apps](https://appstoreconnect.apple.com/apps).
2. Click **+** $\rightarrow$ **New App**.
3. Choose:
   - **Platform**: `iOS`
   - **Name**: `Haven - Home Assistant Client` (or `Haven`)
   - **Primary Language**: `English (US)`
   - **Bundle ID**: Select `org.bilien.haven`
   - **SKU**: `haven-ios-client`
   - **User Access**: `Full Access`
4. Click **Create**.

### Step 3: Archive & Upload Build
1. Open the project in Xcode:
   ```bash
   open NativeHA.xcodeproj
   ```
2. In the target editor under **Signing & Capabilities**:
   - Ensure **Automatically manage signing** is checked.
   - Select your **Team** (`Apple Development: johan+apple@bilien.org (5RN24MB5AH)`).
3. In the top menu, select target **Haven** and destination **Any iOS Device (arm64)**.
4. Select **Product** $\rightarrow$ **Archive** (or run `./scripts/build_appstore_archive.sh`).
5. When Xcode Organizer opens:
   - Click **Distribute App**.
   - Select **App Store Connect** $\rightarrow$ **Upload**.
   - Follow the prompts to upload the build.

### Step 4: Complete App Store Connect Details & Submit
1. In App Store Connect, upload screenshots (6.9" / 6.7" and 6.5" iPhone sizes).
2. Paste the listing description, keywords, and URLs from Section 1 & 2.
3. Complete the **App Privacy** questionnaire (No data collected).
4. Select the uploaded build under **Build**.
5. Click **Submit for Review**!
