import Foundation

// MARK: - Incoming Message
public struct HAIncomingMessage: Codable, Sendable {
    public let type: String
    public let rawId: String?
    public var id: Int? {
        guard let raw = rawId else { return nil }
        return Int(raw)
    }
    public let success: Bool?
    public let haVersion: String?
    public let message: String?
    public let result: AnyCodable?
    public let error: HAErrorPayload?
    public let event: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case type, id, success, message, result, error, event
        case haVersion = "ha_version"
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
        self.success = try? container.decode(Bool.self, forKey: .success)
        self.haVersion = try? container.decode(String.self, forKey: .haVersion)
        self.message = try? container.decode(String.self, forKey: .message)
        self.result = try? container.decode(AnyCodable.self, forKey: .result)
        self.error = try? container.decode(HAErrorPayload.self, forKey: .error)
        self.event = try? container.decode(AnyCodable.self, forKey: .event)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        if let intId = id {
            try container.encode(intId, forKey: .id)
        } else if let raw = rawId {
            try container.encode(raw, forKey: .id)
        }
        try container.encodeIfPresent(success, forKey: .success)
        try container.encodeIfPresent(haVersion, forKey: .haVersion)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encodeIfPresent(event, forKey: .event)
    }
}

public struct HAErrorPayload: Codable, Sendable {
    public let code: String?
    public let message: String?
}

// MARK: - Outgoing Commands
public struct HAOutgoingCommand: Codable, Sendable {
    public let id: Int
    public let type: String
    public let domain: String?
    public let service: String?
    public let entityId: String?
    public let offer: String?
    public let path: String?
    public let expires: Int?
    public let target: [String: AnyCodable]?
    public let serviceData: [String: AnyCodable]?
    public let urlPath: String?
    
    public init(
        id: Int,
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
    ) {
        self.id = id
        self.type = type
        self.domain = domain
        self.service = service
        self.entityId = entityId
        self.offer = offer
        self.path = path
        self.expires = expires
        self.target = target
        self.serviceData = serviceData
        self.urlPath = urlPath
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, domain, service, target, offer, path, expires
        case entityId = "entity_id"
        case serviceData = "service_data"
        case urlPath = "url_path"
    }
}

// MARK: - Auth Message
public struct HAAuthMessage: Codable, Sendable {
    public let type: String = "auth"
    public let accessToken: String
    
    public init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case accessToken = "access_token"
    }
}
