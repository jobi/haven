import Foundation
import Observation

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
}
