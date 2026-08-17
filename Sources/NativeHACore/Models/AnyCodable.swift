import Foundation

/// A type-erased Codable value representing dynamic JSON primitives, dictionaries, and arrays.
public struct AnyCodable: Codable, Sendable, Hashable {
    public let value: AnySendable
    
    public init(_ value: (any Sendable)?) {
        if let value = value {
            self.value = AnySendable(value)
        } else {
            self.value = AnySendable(NSNull())
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = AnySendable(NSNull())
        } else if let boolVal = try? container.decode(Bool.self) {
            self.value = AnySendable(boolVal)
        } else if let intVal = try? container.decode(Int.self) {
            self.value = AnySendable(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self.value = AnySendable(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self.value = AnySendable(stringVal)
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            self.value = AnySendable(arrayVal)
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            self.value = AnySendable(dictVal)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported AnyCodable value"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value.base {
        case is NSNull:
            try container.encodeNil()
        case let boolVal as Bool:
            try container.encode(boolVal)
        case let intVal as Int:
            try container.encode(intVal)
        case let doubleVal as Double:
            try container.encode(doubleVal)
        case let stringVal as String:
            try container.encode(stringVal)
        case let arrayVal as [AnyCodable]:
            try container.encode(arrayVal)
        case let dictVal as [String: AnyCodable]:
            try container.encode(dictVal)
        default:
            try container.encodeNil()
        }
    }
    
    // MARK: - Accessors
    public var stringValue: String? {
        value.base as? String
    }
    
    public var intValue: Int? {
        if let i = value.base as? Int { return i }
        if let d = value.base as? Double { return Int(d) }
        if let s = value.base as? String { return Int(s) }
        return nil
    }
    
    public var doubleValue: Double? {
        if let d = value.base as? Double { return d }
        if let i = value.base as? Int { return Double(i) }
        if let s = value.base as? String { return Double(s) }
        return nil
    }
    
    public var boolValue: Bool? {
        if let b = value.base as? Bool { return b }
        if let s = value.base as? String {
            if s.lowercased() == "true" || s == "1" { return true }
            if s.lowercased() == "false" || s == "0" { return false }
        }
        return nil
    }
    
    public var arrayValue: [AnyCodable]? {
        value.base as? [AnyCodable]
    }
    
    public var dictionaryValue: [String: AnyCodable]? {
        value.base as? [String: AnyCodable]
    }
    
    public var isNull: Bool {
        value.base is NSNull
    }
}

public struct AnySendable: @unchecked Sendable, Hashable {
    public let base: Any
    
    public init(_ base: Any) {
        self.base = base
    }
    
    public static func == (lhs: AnySendable, rhs: AnySendable) -> Bool {
        switch (lhs.base, rhs.base) {
        case is (NSNull, NSNull):
            return true
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        case let (l as [AnyCodable], r as [AnyCodable]):
            return l == r
        case let (l as [String: AnyCodable], r as [String: AnyCodable]):
            return l == r
        default:
            return false
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch base {
        case is NSNull:
            hasher.combine(0)
        case let b as Bool:
            hasher.combine(b)
        case let i as Int:
            hasher.combine(i)
        case let d as Double:
            hasher.combine(d)
        case let s as String:
            hasher.combine(s)
        case let a as [AnyCodable]:
            hasher.combine(a)
        case let d as [String: AnyCodable]:
            hasher.combine(d)
        default:
            hasher.combine(0)
        }
    }
}
