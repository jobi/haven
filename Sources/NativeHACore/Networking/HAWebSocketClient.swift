import Foundation

public actor HAWebSocketClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    
    private var serverConfig: ServerConfig?
    private var tokenProvider: (@Sendable () async throws -> String)?
    
    private var messageSequence: Int = 1
    private var pendingContinuations: [Int: CheckedContinuation<AnyCodable?, Error>] = [:]
    private var subscriptionHandlers: [Int: @Sendable (AnyCodable) async -> Void] = [:]
    
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
        
        let decoder = JSONDecoder()
        guard let incoming = try? decoder.decode(HAIncomingMessage.self, from: data) else {
            return
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
            if let id = incoming.id, let continuation = pendingContinuations.removeValue(forKey: id) {
                if incoming.success == true {
                    continuation.resume(returning: incoming.result)
                } else {
                    let errMsg = incoming.error?.message ?? "Command failed"
                    continuation.resume(throwing: HAClientError.commandFailed(message: errMsg))
                }
            }
            
        case "event":
            if let id = incoming.id, let handler = subscriptionHandlers[id], let event = incoming.event {
                await handler(event)
            }
            
        case "pong":
            // Heartbeat acknowledged
            break
            
        default:
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
    
    private func handleConnectionDrop(error: Error) async {
        guard !isIntentionalDisconnect else { return }
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        if Task.isCancelled {
            return
        }
        
        heartbeatTask?.cancel()
        heartbeatTask = nil
        
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
