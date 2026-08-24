import Foundation
import Observation
import OSLog

@Observable
@MainActor
public final class EntityStore {
    public private(set) var entities: [String: HAEntityState] = [:]
    public var lastUpdated: Date = Date()
    
    private weak var wsClient: HAWebSocketClient?
    
    public init(wsClient: HAWebSocketClient? = nil) {
        self.wsClient = wsClient
    }
    
    public func setWebSocketClient(_ client: HAWebSocketClient) {
        self.wsClient = client
    }
    
    public func entity(for entityId: String) -> HAEntityState? {
        entities[entityId]
    }
    
    // MARK: - State Ingestion (Compressed subscribe_entities Protocol)
    public func processEntityEvent(_ eventPayload: AnyCodable) {
        guard let dict = eventPayload.dictionaryValue else { return }
        
        // 1. Full State Dump: "a" key contains all entities
        if let initialDump = dict["a"]?.dictionaryValue {
            var newMap: [String: HAEntityState] = [:]
            for (entityId, rawEntityData) in initialDump {
                if let entityState = parseEntityDump(entityId: entityId, data: rawEntityData) {
                    newMap[entityId] = entityState
                }
            }
            self.entities = newMap
            self.lastUpdated = Date()
            return
        }
        
        // 2. Compressed Delta Updates: "c" key contains modified entities
        if let compressedDeltas = dict["c"]?.dictionaryValue {
            for (entityId, deltaValue) in compressedDeltas {
                applyDelta(entityId: entityId, delta: deltaValue)
            }
            self.lastUpdated = Date()
            return
        }
        
        // 3. Fallback: Full single state_changed event
        if let data = dict["data"]?.dictionaryValue,
           let newState = data["new_state"]?.dictionaryValue,
           let entityId = newState["entity_id"]?.stringValue {
            let stateStr = newState["state"]?.stringValue ?? "unknown"
            let attrs = newState["attributes"]?.dictionaryValue ?? [:]
            self.entities[entityId] = HAEntityState(
                entityId: entityId,
                state: stateStr,
                attributes: attrs,
                lastUpdated: Date()
            )
            self.lastUpdated = Date()
        }
    }
    
    private func parseEntityDump(entityId: String, data: AnyCodable) -> HAEntityState? {
        guard let entityDict = data.dictionaryValue else { return nil }
        let stateStr = entityDict["s"]?.stringValue ?? "unknown"
        let attrs = entityDict["a"]?.dictionaryValue ?? [:]
        
        var lastChanged: Date? = nil
        if let lc = entityDict["lc"]?.doubleValue {
            lastChanged = Date(timeIntervalSince1970: lc)
        }
        
        var lastUpdated: Date? = nil
        if let lu = entityDict["lu"]?.doubleValue {
            lastUpdated = Date(timeIntervalSince1970: lu)
        }
        
        return HAEntityState(
            entityId: entityId,
            state: stateStr,
            attributes: attrs,
            lastChanged: lastChanged,
            lastUpdated: lastUpdated
        )
    }
    
    private func applyDelta(entityId: String, delta: AnyCodable) {
        guard let deltaDict = delta.dictionaryValue else { return }
        var current = entities[entityId] ?? HAEntityState(entityId: entityId, state: "unknown")
        
        // Check for additions/modifications under "+"
        if let additions = deltaDict["+"]?.dictionaryValue {
            var updatedState = current.state
            var updatedAttrs = current.attributes
            
            if let newState = additions["s"]?.stringValue {
                updatedState = newState
            }
            
            if let newAttrs = additions["a"]?.dictionaryValue {
                for (k, v) in newAttrs {
                    updatedAttrs[k] = v
                }
            }
            
            current = HAEntityState(
                entityId: entityId,
                state: updatedState,
                attributes: updatedAttrs,
                lastChanged: current.lastChanged,
                lastUpdated: Date()
            )
            entities[entityId] = current
        }
        
        // Check for attribute removals under "-"
        if let removals = deltaDict["-"]?.dictionaryValue, let removedAttrs = removals["a"]?.arrayValue {
            var updatedAttrs = current.attributes
            for key in removedAttrs {
                if let keyStr = key.stringValue {
                    updatedAttrs.removeValue(forKey: keyStr)
                }
            }
            current = HAEntityState(
                entityId: entityId,
                state: current.state,
                attributes: updatedAttrs,
                lastChanged: current.lastChanged,
                lastUpdated: Date()
            )
            entities[entityId] = current
        }
    }
    
    // MARK: - Direct Entity Actions
    public func toggle(entityId: String) async {
        let domain = entityId.components(separatedBy: ".").first ?? "homeassistant"
        let service = (domain == "lock") ? "unlock" : "toggle"
        await callService(
            domain: domain,
            service: service,
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func setBrightness(entityId: String, percentage: Double) async {
        let brightnessValue = Int(min(255, max(0, (percentage / 100.0) * 255.0)))
        await callService(
            domain: "light",
            service: "turn_on",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["brightness": AnyCodable(brightnessValue)]
        )
    }
    
    // MARK: - Media Player Actions
    public func mediaPlayPause(entityId: String) async {
        await callService(
            domain: "media_player",
            service: "media_play_pause",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func mediaNextTrack(entityId: String) async {
        await callService(
            domain: "media_player",
            service: "media_next_track",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func mediaPreviousTrack(entityId: String) async {
        await callService(
            domain: "media_player",
            service: "media_previous_track",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func setVolume(entityId: String, level: Double) async {
        let clamped = min(1.0, max(0.0, level))
        await callService(
            domain: "media_player",
            service: "volume_set",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["volume_level": AnyCodable(clamped)]
        )
    }
    
    public func setVolumeMute(entityId: String, isMuted: Bool) async {
        await callService(
            domain: "media_player",
            service: "volume_mute",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["is_volume_muted": AnyCodable(isMuted)]
        )
    }
    
    public func selectSource(entityId: String, source: String) async {
        await callService(
            domain: "media_player",
            service: "select_source",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["source": AnyCodable(source)]
        )
    }
    
    // MARK: - Light Actions
    public func setLightRGB(entityId: String, r: Int, g: Int, b: Int) async {
        await callService(
            domain: "light",
            service: "turn_on",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["rgb_color": AnyCodable([AnyCodable(r), AnyCodable(g), AnyCodable(b)])]
        )
    }
    
    public func setLightColorTemp(entityId: String, kelvin: Int) async {
        await callService(
            domain: "light",
            service: "turn_on",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["color_temp_kelvin": AnyCodable(kelvin)]
        )
    }
    
    public func setLightEffect(entityId: String, effect: String) async {
        await callService(
            domain: "light",
            service: "turn_on",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["effect": AnyCodable(effect)]
        )
    }
    
    // MARK: - Climate Actions
    public func setTargetTemperature(entityId: String, temperature: Double) async {
        await callService(
            domain: "climate",
            service: "set_temperature",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["temperature": AnyCodable(temperature)]
        )
    }
    
    public func setHVACMode(entityId: String, mode: String) async {
        await callService(
            domain: "climate",
            service: "set_hvac_mode",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["hvac_mode": AnyCodable(mode)]
        )
    }
    
    // MARK: - Cover Actions
    public func openCover(entityId: String) async {
        await callService(
            domain: "cover",
            service: "open_cover",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func closeCover(entityId: String) async {
        await callService(
            domain: "cover",
            service: "close_cover",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func stopCover(entityId: String) async {
        await callService(
            domain: "cover",
            service: "stop_cover",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func setCoverPosition(entityId: String, position: Int) async {
        await callService(
            domain: "cover",
            service: "set_cover_position",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["position": AnyCodable(position)]
        )
    }
    
    // MARK: - Lock Actions
    public func setLock(entityId: String, lock: Bool) async {
        await callService(
            domain: "lock",
            service: lock ? "lock" : "unlock",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    // MARK: - Automation & Scene Actions
    public func triggerAutomation(entityId: String) async {
        await callService(
            domain: "automation",
            service: "trigger",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func turnOn(entityId: String) async {
        let domain = entityId.components(separatedBy: ".").first ?? "homeassistant"
        await callService(
            domain: domain,
            service: "turn_on",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    public func turnOff(entityId: String) async {
        let domain = entityId.components(separatedBy: ".").first ?? "homeassistant"
        await callService(
            domain: domain,
            service: "turn_off",
            target: ["entity_id": AnyCodable(entityId)]
        )
    }
    
    // MARK: - Select & Remote Actions
    public func selectOption(entityId: String, option: String) async {
        let domain = entityId.components(separatedBy: ".").first ?? "select"
        await callService(
            domain: domain,
            service: "select_option",
            target: ["entity_id": AnyCodable(entityId)],
            serviceData: ["option": AnyCodable(option)]
        )
    }
    
    public func selectRemoteActivity(entityId: String, activity: String) async {
        if activity.lowercased() == "poweroff" || activity.lowercased() == "power_off" {
            await callService(
                domain: "remote",
                service: "turn_off",
                target: ["entity_id": AnyCodable(entityId)]
            )
        } else {
            await callService(
                domain: "remote",
                service: "turn_on",
                target: ["entity_id": AnyCodable(entityId)],
                serviceData: ["activity": AnyCodable(activity)]
            )
        }
    }
    
    public var serverURL: URL? {
        get { _serverURL }
        set { _serverURL = newValue }
    }
    private var _serverURL: URL? = nil
    
    public func callService(
        domain: String,
        service: String,
        target: [String: AnyCodable]? = nil,
        serviceData: [String: AnyCodable]? = nil
    ) async {
        guard let client = wsClient else { return }
        do {
            _ = try await client.sendCommand(
                type: "call_service",
                domain: domain,
                service: service,
                target: target,
                serviceData: serviceData
            )
        } catch {
            print("[EntityStore] Service call failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Camera Streaming & Snapshots
    public func getAccessToken() async -> String? {
        if let server = ServerStore.shared.activeServer {
            return try? await HAAuthManager.shared.getValidAccessToken(for: server)
        }
        return nil
    }
    
    public func fetchCameraCapabilities(entityId: String) async -> [String] {
        guard let client = wsClient else { return ["webrtc", "web_rtc", "hls"] }
        if let result = try? await client.sendCommand(
            type: "camera/capabilities",
            entityId: entityId
        ) {
            if let types = result.dictionaryValue?["frontend_stream_types"]?.arrayValue?.compactMap({ $0.stringValue }) {
                Logger(subsystem: "com.nativeha.client", category: "Camera").notice("fetchCameraCapabilities for \(entityId): \(types)")
                var normalized = types
                if types.contains("web_rtc") && !types.contains("webrtc") {
                    normalized.append("webrtc")
                }
                return normalized
            }
        }
        return ["webrtc", "web_rtc", "hls"]
    }
    
    public func signPath(_ path: String, expires: Int = 300) async -> String? {
        guard let client = wsClient else { return nil }
        if let result = try? await client.sendCommand(
            type: "auth/sign_path",
            path: path,
            expires: expires
        ) {
            if let signedPath = result.dictionaryValue?["path"]?.stringValue {
                return signedPath
            }
        }
        return nil
    }
    
    public func fetchSignedCameraSnapshot(entityId: String, width: Int = 946) async -> Data? {
        guard let serverURL = serverURL else { return nil }
        let basePath = "/api/camera_proxy/\(entityId)"
        
        let pathWithSig: String
        if let signed = await signPath(basePath, expires: 300) {
            pathWithSig = signed
        } else {
            pathWithSig = basePath
        }
        
        let base = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = pathWithSig.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let delimiter = cleanPath.contains("?") ? "&" : "?"
        let urlStr = "\(base)/\(cleanPath)\(delimiter)width=\(width)&height=0"
        
        guard let url = URL(string: urlStr) ?? URL(string: "\(base)/\(cleanPath)") else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), data.count > 100 {
                return data
            }
        } catch {
            print("[EntityStore] fetchSignedCameraSnapshot error: \(error.localizedDescription)")
        }
        return nil
    }
    
    public func sendWebRTCOffer(entityId: String, offer: String) async throws -> String {
        let logger = Logger(subsystem: "com.nativeha.client", category: "Camera")
        guard let client = wsClient else {
            logger.error("sendWebRTCOffer: wsClient is nil")
            throw HAWebSocketClient.HAClientError.notConnected
        }
        
        logger.notice("sendWebRTCOffer: sending offer session for \(entityId) (sdp len: \(offer.count))")
        return try await client.sendWebRTCOfferSession(entityId: entityId, offer: offer)
    }
    
    public func cameraMJPEGStreamURL(entityId: String) async -> URL? {
        guard let serverURL = serverURL else { return nil }
        
        var token: String? = nil
        if let ent = entity(for: entityId) {
            token = ent.attributes["access_token"]?.stringValue
            if token == nil, let pic = ent.attributes["entity_picture"]?.stringValue,
               let comp = URLComponents(string: pic),
               let queryToken = comp.queryItems?.first(where: { $0.name == "token" })?.value {
                token = queryToken
            }
        }
        
        if token == nil {
            token = await getAccessToken()
        }
        
        let base = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urlStr: String
        if let token = token, !token.isEmpty {
            urlStr = "\(base)/api/camera_proxy_stream/\(entityId)?token=\(token)"
        } else {
            urlStr = "\(base)/api/camera_proxy_stream/\(entityId)"
        }
        return URL(string: urlStr)
    }
    
    public func fetchCameraStream(entityId: String) async throws -> URL? {
        guard let client = wsClient, let serverURL = serverURL else { return nil }
        
        if let result = try await client.sendCommand(
            type: "camera/stream",
            entityId: entityId
        ) {
            if let streamPath = result.dictionaryValue?["url"]?.stringValue {
                if streamPath.hasPrefix("http://") || streamPath.hasPrefix("https://") {
                    return URL(string: streamPath)
                } else {
                    let base = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let cleanPath = streamPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    return URL(string: "\(base)/\(cleanPath)")
                }
            }
        }
        return nil
    }
    
    public func fetchCameraSnapshot(entityId: String, entityPicture: String? = nil) async -> Data? {
        guard let serverURL = serverURL else { return nil }
        
        let path: String
        if let pic = entityPicture, !pic.isEmpty {
            path = pic
        } else {
            path = "/api/camera_proxy/\(entityId)"
        }
        
        let fullURLString: String
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            fullURLString = path
        } else {
            let base = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            fullURLString = "\(base)/\(cleanPath)"
        }
        
        guard let url = URL(string: fullURLString) else { return nil }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        
        if let token = await getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            return data
        }
        return nil
    }
}
