import Foundation

public enum HAConnectionState: Sendable, Equatable, CustomStringConvertible {
    case disconnected
    case connecting
    case authenticating
    case connected(haVersion: String)
    case reconnecting(attempt: Int, delay: TimeInterval)
    case failed(error: String)
    
    public var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .authenticating:
            return "Authenticating..."
        case .connected(let v):
            return "Connected (HA \(v))"
        case .reconnecting(let attempt, let delay):
            return "Reconnecting (\(attempt)) in \(Int(delay))s"
        case .failed(let err):
            return "Connection Failed: \(err)"
        }
    }
    
    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
