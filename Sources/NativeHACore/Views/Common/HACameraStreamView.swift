import SwiftUI
import AVKit
import Combine
import OSLog
#if os(iOS)
import UIKit
import WebKit
#endif

/// Native Home Assistant live camera video streaming view with WebRTC, HLS, and signed snapshot support.
public struct HACameraStreamView: View {
    public let entityId: String
    public let entityStore: EntityStore
    public let entityPicture: String?
    
    @State private var streamMode: StreamMode = .webrtc
    @State private var isWebRTCPlaying: Bool = false
    @State private var isConnecting: Bool = true
    @State private var streamError: String? = nil
    @State private var hlsPlayer: AVPlayer? = nil
    @State private var isPlaying: Bool = true
    @State private var isMuted: Bool = true
    @State private var isFullScreen: Bool = false
    @State private var debugStatus: String = "Ready"
    #if os(iOS)
    @State private var staticSnapshot: UIImage? = nil
    #endif
    @State private var snapshotPollingTimer: Timer? = nil
    
    enum StreamMode {
        case webrtc
        case hls
        case snapshot
    }
    
    public init(
        entityId: String,
        entityStore: EntityStore,
        entityPicture: String? = nil
    ) {
        self.entityId = entityId
        self.entityStore = entityStore
        self.entityPicture = entityPicture
    }
    
    private var hasAnyVisualMedia: Bool {
        #if os(iOS)
        return staticSnapshot != nil || isWebRTCPlaying || hlsPlayer != nil
        #else
        return true
        #endif
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Frame
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                
                // 1. Base Layer: Live Signed Snapshot (Instant initial visual)
                #if os(iOS)
                if let snapshot = staticSnapshot, !isWebRTCPlaying {
                    Image(uiImage: snapshot)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                #endif
                
                // 2. Video Layer: WebRTC Stream Player (Active live video stream)
                #if os(iOS)
                if streamMode == .webrtc {
                    HAWebRTCStreamPlayer(
                        entityId: entityId,
                        entityStore: entityStore,
                        isMuted: isMuted,
                        onReady: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.isWebRTCPlaying = true
                                self.isConnecting = false
                                self.streamError = nil
                                self.debugStatus = "WebRTC Live"
                            }
                            self.snapshotPollingTimer?.invalidate()
                            self.snapshotPollingTimer = nil
                        },
                        onError: { error in
                            print("[HACameraStreamView] WebRTC fallback to snapshot stream: \(error)")
                            self.debugStatus = "Error: \(error)"
                            self.streamMode = .snapshot
                            self.isConnecting = false
                        },
                        onStatusUpdate: { status in
                            self.debugStatus = status
                        }
                    )
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                #endif
                
                // 3. Video Layer: HLS Player
                if streamMode == .hls, let player = hlsPlayer {
                    VideoPlayer(player: player)
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                // 4. Loading Spinner (only before any frame or snapshot arrives)
                #if os(iOS)
                if isConnecting && !hasAnyVisualMedia {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text("Connecting live camera...")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                #endif
                
                // 5. Overlays (Live Badge, Full-Screen, Reload, Status Badge)
                VStack {
                    HStack {
                        // Live Indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(hasAnyVisualMedia ? Color.red : Color.gray)
                                .frame(width: 8, height: 8)
                            
                            Text(hasAnyVisualMedia ? "LIVE" : "CONNECTING")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        
                        Spacer()
                        
                        // Full Screen Toggle
                        Button {
                            isFullScreen = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                    }
                    .padding(12)
                    
                    Spacer()
                    
                    // Bottom Control Bar
                    HStack(spacing: 10) {
                        // Mute Toggle
                        Button {
                            toggleMute()
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                        
                        if isConnecting || streamError != nil {
                            Text(streamError ?? debugStatus)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6), in: Capsule())
                        }
                        
                        Spacer()
                        
                        // Refresh Stream Button
                        Button {
                            reloadStream()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6), in: Circle())
                        }
                    }
                    .padding(12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isFullScreen) {
            FullScreenCameraContainerView(
                entityId: entityId,
                entityStore: entityStore,
                streamMode: streamMode,
                hlsPlayer: hlsPlayer,
                staticSnapshot: staticSnapshot,
                isMuted: $isMuted,
                onDismiss: { isFullScreen = false }
            )
        }
        #endif
        .task {
            await startStreamingSession()
        }
        .onDisappear {
            stopStreamingSession()
        }
    }
    
    // MARK: - Stream Lifecycle
    
    private func startStreamingSession() async {
        isConnecting = true
        isWebRTCPlaying = false
        streamError = nil
        debugStatus = "Checking capabilities..."
        
        // 1. Fetch initial signed snapshot immediately
        await fetchSnapshot()
        startSnapshotPolling()
        
        // 2. Discover camera capabilities
        let capabilities = await entityStore.fetchCameraCapabilities(entityId: entityId)
        
        if capabilities.contains("webrtc") || capabilities.contains("web_rtc") {
            Logger(subsystem: "com.nativeha.client", category: "Camera").notice("Starting WebRTC stream session for \(entityId)")
            self.debugStatus = "Starting WebRTC..."
            self.streamMode = .webrtc
        } else if capabilities.contains("hls") {
            Logger(subsystem: "com.nativeha.client", category: "Camera").notice("Starting HLS stream session for \(entityId)")
            self.debugStatus = "Starting HLS..."
            await switchToHLS()
        } else {
            Logger(subsystem: "com.nativeha.client", category: "Camera").notice("Falling back to snapshot mode for \(entityId)")
            self.debugStatus = "Snapshot mode"
            self.streamMode = .snapshot
            self.isConnecting = false
        }
    }
    
    private func switchToHLS() async {
        do {
            if let hlsURL = try await entityStore.fetchCameraStream(entityId: entityId) {
                var assetOptions: [String: Any] = [:]
                if let token = await entityStore.getAccessToken() {
                    assetOptions["AVURLAssetHTTPHeaderFieldsKey"] = ["Authorization": "Bearer \(token)"]
                }
                let asset = AVURLAsset(url: hlsURL, options: assetOptions)
                let item = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: item)
                player.isMuted = isMuted
                self.hlsPlayer = player
                player.play()
                self.streamMode = .hls
                self.isConnecting = false
            } else {
                self.streamMode = .snapshot
                self.isConnecting = false
            }
        } catch {
            print("[HACameraStreamView] HLS stream not supported: \(error.localizedDescription)")
            self.streamMode = .snapshot
            self.isConnecting = false
        }
    }
    
    private func fetchSnapshot() async {
        #if os(iOS)
        // 1. Fetch high-resolution signed camera snapshot
        if let data = await entityStore.fetchSignedCameraSnapshot(entityId: entityId, width: 1280),
           let image = UIImage(data: data) {
            await MainActor.run {
                self.staticSnapshot = image
                self.isConnecting = false
                self.streamError = nil
            }
            return
        }
        
        // 2. Fallback to standard camera snapshot
        if let data = await entityStore.fetchCameraSnapshot(entityId: entityId, entityPicture: entityPicture),
           let image = UIImage(data: data) {
            await MainActor.run {
                self.staticSnapshot = image
                self.isConnecting = false
                self.streamError = nil
            }
        }
        #endif
    }
    
    private func startSnapshotPolling() {
        snapshotPollingTimer?.invalidate()
        snapshotPollingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            Task { @MainActor in
                if self.streamMode == .snapshot || !self.isWebRTCPlaying {
                    await self.fetchSnapshot()
                }
            }
        }
    }
    
    private func stopStreamingSession() {
        hlsPlayer?.pause()
        hlsPlayer = nil
        snapshotPollingTimer?.invalidate()
        snapshotPollingTimer = nil
        isConnecting = false
    }
    
    private func reloadStream() {
        stopStreamingSession()
        Task {
            await startStreamingSession()
        }
    }
    
    private func toggleMute() {
        isMuted.toggle()
        hlsPlayer?.isMuted = isMuted
    }
}

// MARK: - Native WebRTC Player

#if os(iOS)
public struct HAWebRTCStreamPlayer: UIViewRepresentable {
    public let entityId: String
    public let entityStore: EntityStore
    public let isMuted: Bool
    public let onReady: () -> Void
    public let onError: (String) -> Void
    public let onStatusUpdate: (String) -> Void
    
    public init(
        entityId: String,
        entityStore: EntityStore,
        isMuted: Bool = true,
        onReady: @escaping () -> Void = {},
        onError: @escaping (String) -> Void = { _ in },
        onStatusUpdate: @escaping (String) -> Void = { _ in }
    ) {
        self.entityId = entityId
        self.entityStore = entityStore
        self.isMuted = isMuted
        self.onReady = onReady
        self.onError = onError
        self.onStatusUpdate = onStatusUpdate
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "sendOffer")
        contentController.add(context.coordinator, name: "streamReady")
        contentController.add(context.coordinator, name: "streamError")
        contentController.add(context.coordinator, name: "log")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        context.coordinator.webView = webView
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; display: flex; align-items: center; justify-content: center; }
                video { width: 100%; height: 100%; object-fit: contain; background: transparent; }
            </style>
        </head>
        <body>
            <video id="video" autoplay playsinline muted></video>
            <script>
                function log(msg) {
                    window.webkit.messageHandlers.log.postMessage(String(msg));
                }
                
                window.onerror = function(msg, url, line) {
                    log("JS Error: " + msg + " (line " + line + ")");
                };
                
                let isInitialized = false;
                async function initWebRTC() {
                    if (isInitialized) return;
                    isInitialized = true;
                    log("Starting WebRTC connection...");
                    try {
                        const config = {
                            iceServers: [
                                { urls: "stun:stun.l.google.com:19302" },
                                { urls: "stun:stun1.l.google.com:19302" }
                            ],
                            sdpSemantics: "unified-plan"
                        };
                        const pc = new RTCPeerConnection(config);
                        window.pc = pc;
                        
                        let hasReceivedTrack = false;
                        
                        pc.addEventListener("iceconnectionstatechange", () => {
                            log("ICE: " + pc.iceConnectionState);
                        });
                        pc.addEventListener("connectionstatechange", () => {
                            log("Peer: " + pc.connectionState);
                        });
                        pc.addEventListener("signalingstatechange", () => {
                            log("Signaling: " + pc.signalingState);
                        });
                        
                        // Google Nest WebRTC requires m-lines in order: audio, video, application
                        pc.addTransceiver("audio", { direction: "recvonly" });
                        pc.addTransceiver("video", { direction: "recvonly" });
                        pc.createDataChannel("dataSendChannel");
                        
                        pc.ontrack = (event) => {
                            log("Received track: " + event.track.kind);
                            hasReceivedTrack = true;
                            const video = document.getElementById("video");
                            const stream = (event.streams && event.streams[0]) ? event.streams[0] : new MediaStream([event.track]);
                            video.srcObject = stream;
                            video.muted = \(isMuted);
                            video.play().then(() => {
                                log("Video playing!");
                                window.webkit.messageHandlers.streamReady.postMessage("ready");
                            }).catch(e => {
                                log("Play error: " + e.message);
                            });
                        };
                        
                        // Fallback timeout: Google Nest WebRTC requires 5-10 seconds to negotiate with cloud
                        setTimeout(() => {
                            if (!hasReceivedTrack) {
                                log("Timeout (35s), fallback to snapshot");
                                window.webkit.messageHandlers.streamError.postMessage("WebRTC track timeout");
                            }
                        }, 35000);
                        
                        const offer = await pc.createOffer();
                        await pc.setLocalDescription(offer);
                        log("Gathering ICE candidates...");
                        
                        if (pc.iceGatheringState !== "complete") {
                            await new Promise(resolve => {
                                const checkState = () => {
                                    if (pc.iceGatheringState === "complete") {
                                        pc.removeEventListener("icegatheringstatechange", checkState);
                                        resolve();
                                    }
                                };
                                pc.addEventListener("icegatheringstatechange", checkState);
                                setTimeout(resolve, 2500);
                            });
                        }
                        
                        log("Sending offer SDP...");
                        window.webkit.messageHandlers.sendOffer.postMessage(pc.localDescription.sdp);
                        
                        window.handleAnswer = async (answerSdp) => {
                            log("Applying remote answer...");
                            try {
                                await pc.setRemoteDescription(new RTCSessionDescription({ type: "answer", sdp: answerSdp }));
                                log("Remote answer applied!");
                            } catch (err) {
                                log("Answer error: " + err.message);
                                window.webkit.messageHandlers.streamError.postMessage(err.message);
                            }
                        };
                    } catch (err) {
                        log("Init error: " + err.message);
                        window.webkit.messageHandlers.streamError.postMessage(err.message);
                    }
                }
                
                initWebRTC();
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: entityStore.serverURL ?? URL(string: "https://homeassistant.local"))
        return webView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.evaluateJavaScript("if (document.getElementById('video')) { document.getElementById('video').muted = \(isMuted); }", completionHandler: nil)
    }
    
    public final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
        let parent: HAWebRTCStreamPlayer
        weak var webView: WKWebView?
        
        init(_ parent: HAWebRTCStreamPlayer) {
            self.parent = parent
        }
        
        @available(iOS 15.0, *)
        public func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            Logger(subsystem: "com.nativeha.client", category: "Camera").notice("[HAWebRTC] Granting media capture permission for WebRTC")
            decisionHandler(.grant)
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Logger(subsystem: "com.nativeha.client", category: "Camera").notice("[HAWebRTC] WKWebView didFinish navigation, invoking initWebRTC()")
            webView.evaluateJavaScript("if (typeof initWebRTC === 'function') { initWebRTC(); }", completionHandler: nil)
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger(subsystem: "com.nativeha.client", category: "Camera").error("[HAWebRTC] WKWebView didFail: \(error.localizedDescription)")
            parent.onStatusUpdate("WebView failed: \(error.localizedDescription)")
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let logger = Logger(subsystem: "com.nativeha.client", category: "Camera")
            if message.name == "log", let logMsg = message.body as? String {
                logger.notice("[HAWebRTC-JS] \(logMsg)")
                parent.onStatusUpdate(logMsg)
            } else if message.name == "sendOffer", let offerSdp = message.body as? String {
                Task { @MainActor in
                    do {
                        self.parent.onStatusUpdate("Sending offer to HA...")
                        logger.notice("[HAWebRTC] Sending offer for \(self.parent.entityId)...")
                        let answerSdp = try await self.parent.entityStore.sendWebRTCOffer(entityId: self.parent.entityId, offer: offerSdp)
                        self.parent.onStatusUpdate("Received answer (\(answerSdp.count)b)")
                        logger.notice("[HAWebRTC] Received SDP answer from Home Assistant (length: \(answerSdp.count))")
                        if let jsonAnswer = try? JSONEncoder().encode(answerSdp),
                           let strAnswer = String(data: jsonAnswer, encoding: .utf8) {
                            _ = try? await self.webView?.evaluateJavaScript("window.handleAnswer(\(strAnswer));")
                        }
                    } catch {
                        self.parent.onStatusUpdate("Err: \(error.localizedDescription)")
                        logger.error("[HAWebRTC] HA error: \(error.localizedDescription)")
                        self.parent.onError("WebRTC error: \(error.localizedDescription)")
                    }
                }
            } else if message.name == "streamReady" {
                Task { @MainActor in
                    self.parent.onStatusUpdate("Stream Ready")
                    logger.notice("[HAWebRTC] Stream is ready and playing!")
                    parent.onReady()
                }
            } else if message.name == "streamError", let errorMsg = message.body as? String {
                Task { @MainActor in
                    self.parent.onStatusUpdate("Error: \(errorMsg)")
                    logger.error("[HAWebRTC] Stream error: \(errorMsg)")
                    parent.onError(errorMsg)
                }
            }
        }
    }
}

// MARK: - Full Screen Camera View

struct FullScreenCameraContainerView: View {
    let entityId: String
    let entityStore: EntityStore
    let streamMode: HACameraStreamView.StreamMode
    let hlsPlayer: AVPlayer?
    let staticSnapshot: UIImage?
    @Binding var isMuted: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let img = staticSnapshot {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }
            
            if streamMode == .webrtc {
                HAWebRTCStreamPlayer(
                    entityId: entityId,
                    entityStore: entityStore,
                    isMuted: isMuted
                )
                .ignoresSafeArea()
            } else if let player = hlsPlayer {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
            // Overlay controls
            VStack {
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                        Text("LIVE")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .padding()
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button {
                        isMuted.toggle()
                        hlsPlayer?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(14)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}
#endif
