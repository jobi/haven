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
- **Privacy Policy URL**: A publicly accessible URL stating privacy practices (e.g. `https://github.com/jobi/nativeha/blob/main/docs/PRIVACY_POLICY.md` or a GitHub Pages link).
- **Support URL**: `https://github.com/jobi/nativeha/issues` (or personal support webpage).
- **Marketing URL** *(Optional)*: `https://github.com/jobi/nativeha`

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

## 4. App Review Information

Provide the following in the **App Review Notes** field to ensure seamless approval by the Apple Review Team:

### Reviewer Notes Copy:
```
Haven is a client for the open-source Home Assistant smart home platform. It communicates directly with a user's self-hosted Home Assistant server via standard HTTP REST and WebSocket APIs.

To test the application:
1. Users enter their Home Assistant server URL (e.g. https://demo.home-assistant.io or their personal local/Tailscale URL).
2. The app uses standard OAuth2 / Long-Lived Access Token authorization directly on the user's server.
3. No account creation with our app is required; credentials are authenticated directly against Home Assistant and stored locally in the secure iOS Keychain.
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
