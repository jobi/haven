import Foundation
import OSLog

public actor HAWebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    
    private var serverConfig: ServerConfig?
    private var tokenProvider: (@Sendable () async throws -> String)?
    
    private var messageSequence: Int = 1
    private var pendingContinuations: [Int: CheckedContinuation<AnyCodable?, Error>] = [:]
    private var subscriptionHandlers: [Int: @Sendable (AnyCodable) async -> Void] = [:]
    private var stringSubscriptionHandlers: [String: @Sendable (AnyCodable) async -> Void] = [:]
    
    private var isIntentionalDisconnect: Bool = false
    private var reconnectAttempt: Int = 0
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    
    public private(set) var state: HAConnectionState = .disconnected {
        didSet {
            onStateChanged?(state)
        }
    }
    
    public var onStateChanged: (@Sendable (HAConnectionState) -> Void)?
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    // MARK: - Connection Lifecycle
    public func connect(
        server: ServerConfig,
        tokenProvider: @escaping @Sendable () async throws -> String
    ) async {
        self.serverConfig = server
        self.tokenProvider = tokenProvider
        self.isIntentionalDisconnect = false
        self.reconnectAttempt = 0
        
        await performConnect()
    }
    
    private func performConnect() async {
        guard let server = serverConfig else { return }
        
        state = .connecting
        
        // Convert http/https URL to ws/wss
        guard var components = URLComponents(url: server.url, resolvingAgainstBaseURL: true) else {
            state = .failed(error: "Invalid server URL")
            return
        }
        
        if components.scheme == "https" {
            components.scheme = "wss"
        } else {
            components.scheme = "ws"
        }
        
        var basePath = components.path
        while basePath.hasSuffix("/") {
            basePath.removeLast()
        }
        if !basePath.hasPrefix("/") {
            basePath = "/" + basePath
        }
        components.path = (basePath == "/" ? "" : basePath) + "/api/websocket"
        
        guard let wsURL = components.url else {
            state = .failed(error: "Invalid WebSocket URL")
            return
        }
        
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = session.webSocketTask(with: wsURL)
        webSocketTask?.resume()
        
        startReceiveLoop()
    }
    
    public func disconnect() {
        isIntentionalDisconnect = true
        heartbeatTask?.cancel()
        heartbeatTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        // Cancel all pending continuations
        for (_, cont) in pendingContinuations {
            cont.resume(throwing: HAClientError.disconnected)
        }
        pendingContinuations.removeAll()
        subscriptionHandlers.removeAll()
        
        state = .disconnected
    }
    
    // MARK: - Message Loop
    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                do {
                    guard let task = await self.getCurrentWebSocketTask() else { break }
                    let message = try await task.receive()
                    await self.handleWebSocketMessage(message)
                } catch {
                    if !Task.isCancelled {
                        await self.handleConnectionDrop(error: error)
                    }
                    break
                }
            }
        }
    }
    
    private func getCurrentWebSocketTask() -> URLSessionWebSocketTask? {
        return webSocketTask
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let s):
            guard let d = s.data(using: .utf8) else { return }
            data = d
        @unknown default:
            return
        }
        
        let rawDict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let decoder = JSONDecoder()
        guard let incoming = try? decoder.decode(HAIncomingMessage.self, from: data) else {
            if let raw = rawDict, let id = raw["id"] as? Int, let handler = subscriptionHandlers[id] {
                await handler(AnyCodable(raw))
            }
            return
        }
        
        let logger = Logger(subsystem: "com.nativeha.client", category: "Camera")
        if let id = incoming.id, subscriptionHandlers[id] != nil {
            logger.notice("Received WS message on subscription id \(id): type=\(incoming.type), raw=\(String(describing: rawDict))")
        }
        
        switch incoming.type {
        case "auth_required":
            state = .authenticating
            await sendAuthentication()
            
        case "auth_ok":
            state = .connected(haVersion: incoming.haVersion ?? "Unknown")
            reconnectAttempt = 0
            startHeartbeat()
            
        case "auth_invalid":
            state = .failed(error: incoming.message ?? "Authentication invalid")
            disconnect()
            
        case "result":
            if let id = incoming.id {
                if let handler = subscriptionHandlers[id] {
                    let eventData = incoming.result ?? AnyCodable(rawDict)
                    await handler(eventData)
                    
                    if let subId = incoming.result?.dictionaryValue?["subscription_id"]?.stringValue {
                        stringSubscriptionHandlers[subId] = handler
                    } else if let resDict = rawDict?["result"] as? [String: Any], let subId = resDict["subscription_id"] as? String {
                        stringSubscriptionHandlers[subId] = handler
                    }
                }
                
                if let continuation = pendingContinuations.removeValue(forKey: id) {
                    if incoming.success == true {
                        continuation.resume(returning: incoming.result)
                    } else {
                        let errMsg = incoming.error?.message ?? "Command failed"
                        continuation.resume(throwing: HAClientError.commandFailed(message: errMsg))
                    }
                }
            }
            
        case "event":
            if let rawId = incoming.rawId {
                if let handler = stringSubscriptionHandlers[rawId] {
                    let eventData = incoming.event ?? AnyCodable(rawDict)
                    await handler(eventData)
                }
                if let intId = incoming.id, let handler = subscriptionHandlers[intId] {
                    let eventData = incoming.event ?? AnyCodable(rawDict)
                    await handler(eventData)
                }
            }
            
        case "pong":
            // Heartbeat acknowledged
            break
            
        default:
            if let rawId = incoming.rawId {
                if let handler = stringSubscriptionHandlers[rawId] {
                    let eventData = incoming.event ?? AnyCodable(rawDict)
                    await handler(eventData)
                }
                if let intId = incoming.id, let handler = subscriptionHandlers[intId] {
                    let eventData = incoming.event ?? AnyCodable(rawDict)
                    await handler(eventData)
                }
            }
            break
        }
    }
    
    private func sendAuthentication() async {
        guard let tokenProvider = tokenProvider else {
            state = .failed(error: "No token provider available")
            return
        }
        
        do {
            let token = try await tokenProvider()
            let authMsg = HAAuthMessage(accessToken: token)
            let data = try JSONEncoder().encode(authMsg)
            guard let jsonString = String(data: data, encoding: .utf8) else { return }
            try await webSocketTask?.send(.string(jsonString))
        } catch {
            state = .failed(error: "Failed to retrieve access token: \(error.localizedDescription)")
        }
    }
    
    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                guard let self = self else { break }
                await self.sendPing()
            }
        }
    }
    
    private func sendPing() async {
        let seq = nextSequenceId()
        let pingDict: [String: AnyCodable] = [
            "id": AnyCodable(seq),
            "type": AnyCodable("ping")
        ]
        if let data = try? JSONEncoder().encode(pingDict), let str = String(data: data, encoding: .utf8) {
            try? await webSocketTask?.send(.string(str))
        }
    }
    
    private func handleConnectionDrop(error: Error?) async {
        guard !isIntentionalDisconnect else { return }
        
        reconnectAttempt += 1
        let delay = min(30.0, pow(2.0, Double(reconnectAttempt)))
        state = .reconnecting(attempt: reconnectAttempt, delay: delay)
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        if !isIntentionalDisconnect && !Task.isCancelled {
            await performConnect()
        }
    }
    
    // MARK: - Command Execution
    public func sendCommand(
        type: String,
        domain: String? = nil,
        service: String? = nil,
        entityId: String? = nil,
        offer: String? = nil,
        path: String? = nil,
        expires: Int? = nil,
        target: [String: AnyCodable]? = nil,
        serviceData: [String: AnyCodable]? = nil,
        urlPath: String? = nil
    ) async throws -> AnyCodable? {
        guard state.isConnected else {
            throw HAClientError.notConnected
        }
        
        let id = nextSequenceId()
        let cmd = HAOutgoingCommand(
            id: id,
            type: type,
            domain: domain,
            service: service,
            entityId: entityId,
            offer: offer,
            path: path,
            expires: expires,
            target: target,
            serviceData: serviceData,
            urlPath: urlPath
        )
        
        let data = try JSONEncoder().encode(cmd)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw HAClientError.serializationFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.pendingContinuations[id] = continuation
            Task {
                do {
                    try await self.webSocketTask?.send(.string(jsonString))
                } catch {
                    self.pendingContinuations.removeValue(forKey: id)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - WebRTC Stream Offer Session
    public func sendWebRTCOfferSession(entityId: String, offer: String) async throws -> String {
        guard state.isConnected else {
            throw HAClientError.notConnected
        }
        
        let id = nextSequenceId()
        let cmd = HAOutgoingCommand(
            id: id,
            type: "camera/webrtc/offer",
            entityId: entityId,
            offer: offer
        )
        
        let data = try JSONEncoder().encode(cmd)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw HAClientError.serializationFailed
        }
        
        @Sendable func extractSDP(from any: AnyCodable?) -> String? {
            guard let any = any else { return nil }
            if let str = any.stringValue, str.hasPrefix("v=0") || str.contains("m=video") {
                return str
            }
            if let dict = any.dictionaryValue {
                if let answer = dict["answer"]?.stringValue, !answer.isEmpty {
                    return answer
                }
                if let sdp = dict["sdp"]?.stringValue, !sdp.isEmpty {
                    return sdp
                }
                if let eventObj = dict["event"], let nested = extractSDP(from: eventObj) {
                    return nested
                }
                if let resultObj = dict["result"], let nested = extractSDP(from: resultObj) {
                    return nested
                }
            }
            return nil
        }
        
        return try await withThrowingTaskGroup(of: String.self) { group in
            let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
            
            let eventHandler: @Sendable (AnyCodable) async -> Void = { event in
                let logger = Logger(subsystem: "com.nativeha.client", category: "Camera")
                logger.notice("WebRTC event received: \(String(describing: event))")
                
                if let dict = event.dictionaryValue, let type = dict["type"]?.stringValue, type == "error" {
                    let msg = dict["message"]?.stringValue ?? "WebRTC negotiation failed"
                    logger.error("WebRTC returned error event: \(msg)")
                    continuation.finish(throwing: HAClientError.commandFailed(message: msg))
                    return
                }
                
                if let sdp = extractSDP(from: event) {
                    continuation.yield(sdp)
                }
            }
            
            self.subscriptionHandlers[id] = eventHandler
            
            // Task 1: Dispatch command and wait for answer event or immediate result
            group.addTask {
                let res = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<AnyCodable?, Error>) in
                    Task {
                        await self.registerContinuation(id: id, cont: cont)
                        do {
                            try await self.webSocketTask?.send(.string(jsonString))
                        } catch {
                            await self.deregisterContinuation(id: id)
                            cont.resume(throwing: error)
                        }
                    }
                }
                
                if let directAnswer = extractSDP(from: res) {
                    return directAnswer
                }
                
                if let subId = res?.dictionaryValue?["subscription_id"]?.stringValue {
                    let logger = Logger(subsystem: "com.nativeha.client", category: "Camera")
                    logger.notice("WebRTC session subscription_id received: \(subId)")
                    await self.registerStringSubscriptionHandler(id: subId, handler: eventHandler)
                }
                
                for try await asyncAnswer in stream {
                    return asyncAnswer
                }
                throw HAClientError.commandFailed(message: "No SDP answer received from stream")
            }
            
            // Task 2: 35-second timeout for cloud SDP answer
            group.addTask {
                try await Task.sleep(nanoseconds: 35_000_000_000)
                throw HAClientError.commandFailed(message: "WebRTC cloud answer timed out (35s)")
            }
            
            let result = try await group.next()!
            group.cancelAll()
            self.subscriptionHandlers.removeValue(forKey: id)
            return result
        }
    }
    
    private func registerStringSubscriptionHandler(id: String, handler: @escaping @Sendable (AnyCodable) async -> Void) {
        stringSubscriptionHandlers[id] = handler
    }
    
    private func registerContinuation(id: Int, cont: CheckedContinuation<AnyCodable?, Error>) {
        pendingContinuations[id] = cont
    }
    
    private func deregisterContinuation(id: Int) {
        pendingContinuations.removeValue(forKey: id)
    }
    
    // MARK: - Subscriptions
    public func subscribe(
        type: String,
        eventHandler: @escaping @Sendable (AnyCodable) async -> Void
    ) async throws -> Int {
        guard state.isConnected else {
            throw HAClientError.notConnected
        }
        
        let id = nextSequenceId()
        subscriptionHandlers[id] = eventHandler
        
        let subDict: [String: AnyCodable] = [
            "id": AnyCodable(id),
            "type": AnyCodable(type)
        ]
        let data = try JSONEncoder().encode(subDict)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw HAClientError.serializationFailed
        }
        
        try await webSocketTask?.send(.string(jsonString))
        return id
    }
    
    public func unsubscribe(subscriptionId: Int) async {
        subscriptionHandlers.removeValue(forKey: subscriptionId)
    }
    
    private func nextSequenceId() -> Int {
        let current = messageSequence
        messageSequence += 1
        return current
    }
    
    public enum HAClientError: Error, LocalizedError {
        case notConnected
        case disconnected
        case serializationFailed
        case commandFailed(message: String)
        
        public var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Not connected to Home Assistant."
            case .disconnected:
                return "The connection was interrupted."
            case .serializationFailed:
                return "Failed to serialize message payload."
            case .commandFailed(let msg):
                return "Home Assistant error: \(msg)"
            }
        }
    }
}
