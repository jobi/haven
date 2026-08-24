# Camera Streaming Architecture & Learnings

This document serves as an exhaustive technical reference on camera video streaming in Haven for both human engineers and AI coding assistants. It covers Home Assistant stream protocols, WebRTC signaling internals, Google Nest Smart Device Management (SDM) specifications, and iOS WebKit media lifecycle quirks.

---

## 1. High-Level Streaming Architecture

Haven implements a tiered, capabilities-based camera engine:

```
                  ┌───────────────────────────────┐
                  │ Fetch Camera Capabilities     │
                  │ (camera/capabilities)         │
                  └──────────────┬────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
   ["web_rtc"]                ["hls"]                Fallback
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ WebKit WebRTC   │     │ Native AVPlayer │     │ Signed Snapshot │
│ Stream Engine   │     │ (HLS / m3u8)    │     │ 1.5s Polling    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

1. **WebRTC Mode (Zero-latency P2P / WebRTC)**: Used for WebRTC-capable cameras (e.g., Google Nest, go2rtc, WebRTC camera integrations). Streams at 30fps with sub-second latency.
2. **HLS Mode (HTTP Live Streaming)**: Used for cameras providing RTSP/HLS feeds transcode-streamed through Home Assistant's `stream` component.
3. **Signed Snapshot Polling (Fallback / Initial Placeholder)**: Used as an instant visual placeholder before WebRTC negotiates, and as a fallback for simple snapshot-only cameras.

---

## 2. WebRTC Signaling in Home Assistant

### 2.1 Capability Strings
Home Assistant returns supported stream types via `camera/capabilities`:
- `frontend_stream_types: ["web_rtc"]` (note the underscore in modern HA) or `["webrtc"]`.
- Always normalize both `web_rtc` and `webrtc` when determining player mode.

### 2.2 Modern Home Assistant (>= 2024.11) WebSocket Signaling
In Home Assistant 2024.11+, WebRTC signaling was refactored from a synchronous call (`camera/web_rtc_offer`) to an **asynchronous subscription command** (`camera/webrtc/offer`).

#### Step 1: Client sends offer command
```json
{
  "id": 12,
  "type": "camera/webrtc/offer",
  "entity_id": "camera.backyard",
  "offer": "v=0\r\no=- ..."
}
```

#### Step 2: Home Assistant acknowledges with session identifier
Home Assistant immediately returns a `result` message acknowledging command receipt and establishing a streaming session:
```json
{
  "id": 12,
  "type": "result",
  "success": true,
  "result": {
    "subscription_id": "01M0SJMMASMTAQ5M4RP8XQT6JS"
  }
}
```
*(Note: In some integrations or older providers, `result` may be `null` or contain the SDP answer directly. Always check for direct answers first before awaiting the asynchronous event).*

#### Step 3: Asynchronous SDP Answer Delivery
Because third-party camera cloud services (such as Google Nest SDM) negotiate the connection in the background (typically taking 3–6 seconds), Home Assistant pushes the SDP Answer asynchronously as an **`event`** message.

**Critical Protocol Detail**: The `id` field in the event message is the **hex UUID string session ID**, *not* the integer command sequence number:
```json
{
  "id": "01M0SJMMASMTAQ5M4RP8XQT6JS",
  "type": "event",
  "event": {
    "type": "answer",
    "answer": "v=0\r\no=- ..."
  }
}
```
If negotiation fails on the cloud side, Home Assistant pushes an error event:
```json
{
  "id": "01M0SJMMASMTAQ5M4RP8XQT6JS",
  "type": "event",
  "event": {
    "type": "error",
    "code": "webrtc_offer_failed",
    "message": "Nest API error: ..."
  }
}
```

### 2.3 Polymorphic WebSocket Message IDs
Because Home Assistant WebSocket messages can have either integer IDs (`id: 12`) or string UUID IDs (`id: "01M0SJ..."`), all incoming message decoders must handle polymorphic ID types. In Swift:

```swift
public struct HAIncomingMessage: Codable, Sendable {
    public let type: String
    public let rawId: String?
    public var id: Int? {
        guard let raw = rawId else { return nil }
        return Int(raw)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = (try? container.decode(String.self, forKey: .type)) ?? ""
        if let intId = try? container.decode(Int.self, forKey: .id) {
            self.rawId = String(intId)
        } else if let strId = try? container.decode(String.self, forKey: .id) {
            self.rawId = strId
        } else {
            self.rawId = nil
        }
        // ... other properties ...
    }
}
```

---

## 3. Google Nest SDM WebRTC Offer Specifications

Google Nest cameras integrated through Home Assistant's Google Nest / Smart Device Management (SDM) integration enforce strict SDP formatting rules:

### 3.1 Strict Media Description Order
Google Nest SDM API will reject any SDP offer with `400 INVALID_ARGUMENT` if the media lines (`m=`) are not in the exact required sequence:

> **"Invalid offer SDP: Offer must contain each of audio, video and application m lines in that order."**

To satisfy this requirement in JavaScript WebRTC initialization:
```javascript
// 1. Audio transceiver MUST be first
pc.addTransceiver("audio", { direction: "recvonly" });

// 2. Video transceiver MUST be second
pc.addTransceiver("video", { direction: "recvonly" });

// 3. Application DataChannel MUST be third
pc.createDataChannel("dataSendChannel");
```

### 3.2 Candidate Gathering & ICE State
- Google Nest endpoints do not require continuous trickle ICE from the client.
- Await `pc.iceGatheringState === "complete"` before dispatching the local SDP offer to ensure all STUN host/srflx candidates are embedded into the initial offer payload.
- Standard STUN servers (`stun:stun.l.google.com:19302`, `stun:stun1.l.google.com:19302`) should be included in `RTCConfiguration`.

### 3.3 Negotiation Timers
- Cloud-routed SDP negotiation takes **3–8 seconds** on standard broadband connections.
- Set client timeouts (JavaScript fallback and Swift WebSocket task group timeouts) to at least **30–35 seconds** to prevent premature aborts.

---

## 4. iOS WebKit WebRTC Execution & Quirks

Because iOS does not provide a native WebRTC C++/Swift SDK in standard Foundation, Haven embeds a lightweight, transparent `WKWebView` hosting an HTML5 video player and `RTCPeerConnection`.

### 4.1 The Zero-Opacity Throttling Pitfall
**CRITICAL WEBVIEW BEHAVIOR**:
When a `WKWebView` has a SwiftUI modifier `.opacity(0.0)` or is hidden:
- WebKit **suspends JavaScript execution, timers (`setTimeout`, `setInterval`), and WebRTC event loops** to conserve device power.
- As a result, `RTCPeerConnection` ICE gathering will stall, `createOffer()` will never complete, and connection callbacks will cease firing.
- **Solution**: Keep `WKWebView` at normal opacity (`.opacity(1.0)`), and set `webView.isOpaque = false`, `webView.backgroundColor = .clear`, and HTML `body { background: transparent; }`.

### 4.2 WebKit Permissions & Media Configuration
Configure the `WKWebViewConfiguration` and delegates:
```swift
let config = WKWebViewConfiguration()
config.allowsInlineMediaPlayback = true
config.mediaTypesRequiringUserActionForPlayback = []
config.defaultWebpagePreferences.allowsContentJavaScript = true
```

In `WKUIDelegate`, grant media capture permissions for iOS 15+:
```swift
@available(iOS 15.0, *)
public func webView(
    _ webView: WKWebView,
    requestMediaCapturePermissionFor origin: WKSecurityOrigin,
    initiatedByFrame frame: WKFrameInfo,
    type: WKMediaCaptureType,
    decisionHandler: @escaping (WKPermissionDecision) -> Void
) {
    decisionHandler(.grant)
}
```

### 4.3 Bidirectional Script Message Bridge
Communicate between Swift and WebKit using `WKScriptMessageHandler`:
- `sendOffer`: Dispatched from JS with local SDP $\rightarrow$ Swift executes `EntityStore.sendWebRTCOffer` $\rightarrow$ Evaluates `window.handleAnswer(sdp)` in JS.
- `streamReady`: Dispatched from JS when `video.play()` starts $\rightarrow$ Swift transitions UI to live mode.
- `streamError`: Dispatched on error/timeout $\rightarrow$ Swift falls back to snapshot polling.
- `log`: Bridges JS `console.log` into native `OSLog` (`[HAWebRTC-JS]`).

---

## 5. Instant Snapshot Proxying (`auth/sign_path`)

To prevent black screens while WebRTC or HLS initializes:
1. Home Assistant camera proxy endpoints (`/api/camera_proxy/camera.backyard`) require authentication.
2. Rather than appending query tokens that expire, request a signed proxy URL via WebSocket `auth/sign_path`:
   ```json
   {
     "id": 13,
     "type": "auth/sign_path",
     "path": "/api/camera_proxy/camera.backyard"
   }
   ```
   Response: `{ "path": "/api/camera_proxy/camera.backyard?authSig=..." }`.
3. Fetch high-resolution snapshots directly via standard `URLSession` and render as the base image layer behind the transparent WebRTC player.

---

## 6. Summary Checklist for Future Maintainers

| Area | Requirement | Notes |
| :--- | :--- | :--- |
| **Command Type** | `camera/webrtc/offer` | Modern HA 2024.11+ format (not `camera/web_rtc_offer`). |
| **Offer Order** | Audio $\rightarrow$ Video $\rightarrow$ Application | Required by Google Nest SDM; must include DataChannel. |
| **Event Routing** | Match string `subscription_id` | Remote answer arrives on event with string UUID `id`. |
| **WebKit Opacity**| `isOpaque = false`, `opacity = 1.0` | Never set SwiftUI `.opacity(0.0)` on `WKWebView`. |
| **Timeouts** | $\ge 30\text{ seconds}$ | Nest Cloud setup takes 4–8 seconds. |
