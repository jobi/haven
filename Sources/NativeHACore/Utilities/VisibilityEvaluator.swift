import Foundation

@MainActor
public struct VisibilityEvaluator {
    
    /// Evaluates whether a section, card, or badge is visible based on Home Assistant condition rules
    public static func isVisible(
        visibility: [AnyCodable]?,
        entityStore: EntityStore
    ) -> Bool {
        guard let conditions = visibility, !conditions.isEmpty else {
            return true // No conditions specified -> always visible
        }
        
        // In Home Assistant Lovelace, top-level conditions in the array are evaluated with implicit AND
        for conditionItem in conditions {
            if !evaluateCondition(conditionItem, entityStore: entityStore) {
                return false
            }
        }
        
        return true
    }
    
    /// Evaluates a single condition dictionary
    public static func evaluateCondition(
        _ conditionCodable: AnyCodable,
        entityStore: EntityStore
    ) -> Bool {
        guard let conditionDict = conditionCodable.dictionaryValue else {
            return true
        }
        
        let conditionType = conditionDict["condition"]?.stringValue ?? "state"
        
        switch conditionType {
        case "state":
            return evaluateStateCondition(conditionDict, entityStore: entityStore)
            
        case "numeric_state":
            return evaluateNumericStateCondition(conditionDict, entityStore: entityStore)
            
        case "and":
            guard let nested = conditionDict["conditions"]?.arrayValue else { return true }
            return nested.allSatisfy { evaluateCondition($0, entityStore: entityStore) }
            
        case "or":
            guard let nested = conditionDict["conditions"]?.arrayValue else { return true }
            return nested.contains { evaluateCondition($0, entityStore: entityStore) }
            
        case "not":
            guard let nested = conditionDict["conditions"]?.arrayValue else { return true }
            return !nested.allSatisfy { evaluateCondition($0, entityStore: entityStore) }
            
        case "screen", "user":
            // Screen media query or user condition - default to true in mobile client
            return true
            
        default:
            // Fallback for custom or unrecognized condition types
            return true
        }
    }
    
    private static func evaluateStateCondition(
        _ dict: [String: AnyCodable],
        entityStore: EntityStore
    ) -> Bool {
        guard let entityId = dict["entity"]?.stringValue else { return true }
        let currentEntity = entityStore.entity(for: entityId)
        let currentState = currentEntity?.state ?? "unavailable"
        
        // 1. Positive State Match ("state": "on" or "state": ["on", "home"])
        if let targetState = dict["state"] {
            if let expectedSingle = targetState.stringValue {
                if currentState.lowercased() != expectedSingle.lowercased() {
                    return false
                }
            } else if let expectedArray = targetState.arrayValue {
                let stringList = expectedArray.compactMap { $0.stringValue?.lowercased() }
                if !stringList.contains(currentState.lowercased()) {
                    return false
                }
            }
        }
        
        // 2. Negative State Match ("state_not": "off" or "state_not": ["off", "unavailable"])
        if let targetStateNot = dict["state_not"] {
            if let notSingle = targetStateNot.stringValue {
                if currentState.lowercased() == notSingle.lowercased() {
                    return false
                }
            } else if let notArray = targetStateNot.arrayValue {
                let stringList = notArray.compactMap { $0.stringValue?.lowercased() }
                if stringList.contains(currentState.lowercased()) {
                    return false
                }
            }
        }
        
        return true
    }
    
    private static func evaluateNumericStateCondition(
        _ dict: [String: AnyCodable],
        entityStore: EntityStore
    ) -> Bool {
        guard let entityId = dict["entity"]?.stringValue else { return true }
        guard let currentEntity = entityStore.entity(for: entityId),
              let numericValue = Double(currentEntity.state) else {
            return false
        }
        
        if let above = dict["above"]?.doubleValue {
            if numericValue <= above {
                return false
            }
        }
        
        if let below = dict["below"]?.doubleValue {
            if numericValue >= below {
                return false
            }
        }
        
        if let equalTo = dict["equal_to"]?.doubleValue {
            if numericValue != equalTo {
                return false
            }
        }
        
        return true
    }
}
