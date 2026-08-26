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

### App Store Review Resolution Center / Notes Field Copy (< 4,000 chars)

```text
Dear Apple App Review Team,

Below are our detailed responses to the 7 requested items for Haven (org.bilien.haven):

1. SCREEN RECORDING DEMONSTRATING FUNCTIONALITY
A video captured on a physical iPhone is attached demonstrating: fresh launch, Demo Smart Home access, controlling lights/switches/locks/appliances, light brightness & RGB/Kelvin adjustments, 24h interactive sensor history charts, live camera feeds with HUD overlays, and multi-server settings.
• Account Registration/Login: No proprietary account system. Connects directly to self-hosted Home Assistant servers or runs offline in Demo Mode.
• Paid Content/IAPs: None (100% free app).
• User-Generated Content: None (personal smart home utility).
• Sensitive Permissions: None requested (no camera, mic, contacts, location, or ATT required).

2. TESTED DEVICE MODELS & OPERATING SYSTEMS
• Physical Device: iPhone 16 Pro (iOS 18)
• Simulators: iPhone 16 Pro, iPhone 17 Pro, iPhone SE (3rd Gen) (iOS 17.0 - 18.0), iPad Pro 13-inch (M4), iPad Air 11-inch (M3) (iPadOS 17.0 - 18.0).

3. APP FUNCTIONS, TARGET AUDIENCE & VALUE
• Target Audience: Users of the open-source Home Assistant smart home platform.
• Problem Solved: Web-based smart home dashboards can experience high latency and suboptimal mobile touch response.
• Value: Haven is a native SwiftUI client connecting directly via WebSocket/REST with sub-second response times, interactive charts, live WebRTC streaming, and multi-server support without cloud middlemen or tracking.

4. SETUP & TESTING INSTRUCTIONS (NO SERVER REQUIRED)
The app includes a built-in "Demo Smart Home" sandbox for App Review without needing external hardware:
1. Launch Haven.
2. Tap "Explore Demo Smart Home (No Server Required)".
3. An interactive smart home loads immediately with 30+ entities across 3 views:
   • Home: Toggle lights, fans, locks, appliances; tap "Living Room Ceiling" for brightness/color controls; tap "Living Room Temperature" for 24h history charts.
   • Security: View live camera feeds with motion detection bounding boxes.
   • Settings (gear icon): Multi-server switcher and configuration.
(Optional Live Server): Tap Settings -> "Add Another Server" to connect to any Home Assistant instance via OAuth2 or LLAT.

5. EXTERNAL SERVICES, TOOLS & PLATFORMS
• Home Assistant WebSocket/REST API: Direct connection to the user's private server.
• WebRTC/RTSP: Direct peer-to-server video streaming.
• Third-Party Trackers/Cloud: NONE. No backend servers, no analytics, no ads, no payment processors.

6. REGIONAL DIFFERENCES & GLOBAL AVAILABILITY
Functions consistently across all regions without restrictions or geofencing. Automatically adapts temperature units (°C/°F) and time formats to device locale.

7. REGULATORY & THIRD-PARTY MATERIAL DISCLOSURE
• Regulated Industries: None (utility for personal home automation).
• Third-Party Material: Haven is an open-source client (Apache 2.0). Bundled icons are Material Design Icons (Apache 2.0 / Pictogrammers Free License). No unauthorized third-party IP used.
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
