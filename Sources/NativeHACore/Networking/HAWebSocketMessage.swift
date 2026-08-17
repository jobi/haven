import Foundation

// MARK: - Incoming Message
public struct HAIncomingMessage: Codable, Sendable {
    public let type: String
    public let id: Int?
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
    public let target: [String: AnyCodable]?
    public let serviceData: [String: AnyCodable]?
    public let urlPath: String?
    
    public init(
        id: Int,
        type: String,
        domain: String? = nil,
        service: String? = nil,
        target: [String: AnyCodable]? = nil,
        serviceData: [String: AnyCodable]? = nil,
        urlPath: String? = nil
    ) {
        self.id = id
        self.type = type
        self.domain = domain
        self.service = service
        self.target = target
        self.serviceData = serviceData
        self.urlPath = urlPath
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, domain, service, target
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
