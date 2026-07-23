import Foundation

/// Represents the connection state of the OddSockets client.
public enum ConnectionState: String, CaseIterable, Codable {
    /// The client is disconnected.
    case disconnected = "disconnected"
    
    /// The client is connecting.
    case connecting = "connecting"
    
    /// The client is connected.
    case connected = "connected"
    
    /// The client is reconnecting.
    case reconnecting = "reconnecting"
    
    /// The connection has failed.
    case failed = "failed"
}

/// Represents different event types emitted by the OddSockets client.
public enum EventType: String, CaseIterable, Codable {
    /// Emitted when the client connects.
    case connected = "connected"
    
    /// Emitted when the client disconnects.
    case disconnected = "disconnected"
    
    /// Emitted when the client reconnects.
    case reconnected = "reconnected"
    
    /// Emitted when an error occurs.
    case error = "error"
    
    /// Emitted when a message is received.
    case message = "message"
    
    /// Emitted when presence information changes.
    case presence = "presence"
    
    /// Emitted when a worker is assigned.
    case workerAssigned = "worker_assigned"
    
    /// Emitted when reconnection attempts are exhausted.
    case maxReconnectAttemptsReached = "max_reconnect_attempts_reached"
}

/// Type-erased wrapper for any Codable value.
public struct AnyCodable: Codable, Equatable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDictionary)
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "AnyCodable value cannot be encoded"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
    
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        case let (lhs as [Any], rhs as [Any]):
            return lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { AnyCodable($0) == AnyCodable($1) }
        case let (lhs as [String: Any], rhs as [String: Any]):
            return lhs.count == rhs.count && lhs.allSatisfy { key, value in
                guard let rhsValue = rhs[key] else { return false }
                return AnyCodable(value) == AnyCodable(rhsValue)
            }
        default:
            return false
        }
    }
}

// MARK: - AnyCodable Convenience Extensions

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        let dictionary = Dictionary(uniqueKeysWithValues: elements)
        self.init(dictionary)
    }
}

// MARK: - Type Conversion Extensions

extension AnyCodable {
    /// Returns the value as a Bool if possible.
    public var boolValue: Bool? {
        return value as? Bool
    }
    
    /// Returns the value as an Int if possible.
    public var intValue: Int? {
        return value as? Int
    }
    
    /// Returns the value as a Double if possible.
    public var doubleValue: Double? {
        return value as? Double
    }
    
    /// Returns the value as a String if possible.
    public var stringValue: String? {
        return value as? String
    }
    
    /// Returns the value as an Array if possible.
    public var arrayValue: [Any]? {
        return value as? [Any]
    }
    
    /// Returns the value as a Dictionary if possible.
    public var dictionaryValue: [String: Any]? {
        return value as? [String: Any]
    }
}

// MARK: - Worker Assignment Response

internal struct WorkerAssignment: Codable {
    let url: String?
    let workerId: String?
    let session: AnyCodable?

    private enum CodingKeys: String, CodingKey {
        case url
        case workerId
        case session
    }
}

// MARK: - Error Codes

/// Common error codes used throughout the SDK.
public struct ErrorCodes {
    /// Invalid API key format or value.
    public static let invalidApiKey = "INVALID_API_KEY"
    
    /// Connection to OddSockets failed.
    public static let connectionFailed = "CONNECTION_FAILED"
    
    /// Authentication failed.
    public static let authenticationFailed = "AUTHENTICATION_FAILED"
    
    /// Channel access denied.
    public static let channelAccessDenied = "CHANNEL_ACCESS_DENIED"
    
    /// Message delivery failed.
    public static let messageDeliveryFailed = "MESSAGE_DELIVERY_FAILED"
    
    /// Invalid configuration.
    public static let invalidConfiguration = "INVALID_CONFIGURATION"
    
    /// Worker assignment failed.
    public static let workerAssignmentFailed = "WORKER_ASSIGNMENT_FAILED"
    
    /// Maximum reconnection attempts reached.
    public static let maxReconnectAttemptsReached = "MAX_RECONNECT_ATTEMPTS_REACHED"
    
    /// Operation timeout.
    public static let operationTimeout = "OPERATION_TIMEOUT"
    
    /// Invalid channel name.
    public static let invalidChannelName = "INVALID_CHANNEL_NAME"
}

// MARK: - Event Handler Types

/// Type alias for event handlers that return void.
public typealias EventHandler = (Any?) -> Void

/// Type alias for async event handlers.
public typealias AsyncEventHandler = (Any?) async -> Void

/// Type alias for message handlers.
public typealias MessageHandler = (Message) -> Void

/// Type alias for async message handlers.
public typealias AsyncMessageHandler = (Message) async -> Void

// MARK: - Result Types

/// Result type for operations that can fail.
public typealias OddSocketsResult<T> = Result<T, OddSocketsError>

/// Completion handler for async operations.
public typealias CompletionHandler<T> = (OddSocketsResult<T>) -> Void

// MARK: - Utility Extensions

extension ConnectionState {
    /// Whether the connection state represents a connected state.
    public var isConnected: Bool {
        return self == .connected
    }
    
    /// Whether the connection state represents a connecting state.
    public var isConnecting: Bool {
        return self == .connecting || self == .reconnecting
    }
    
    /// Whether the connection state represents a disconnected state.
    public var isDisconnected: Bool {
        return self == .disconnected || self == .failed
    }
}

extension EventType {
    /// Whether the event type represents a connection-related event.
    public var isConnectionEvent: Bool {
        switch self {
        case .connected, .disconnected, .reconnected, .workerAssigned, .maxReconnectAttemptsReached:
            return true
        case .error, .message, .presence:
            return false
        }
    }
    
    /// Whether the event type represents a message-related event.
    public var isMessageEvent: Bool {
        switch self {
        case .message, .presence:
            return true
        case .connected, .disconnected, .reconnected, .error, .workerAssigned, .maxReconnectAttemptsReached:
            return false
        }
    }
}

// MARK: - Debug Descriptions

extension ConnectionState: CustomStringConvertible {
    public var description: String {
        return rawValue.capitalized
    }
}

extension EventType: CustomStringConvertible {
    public var description: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

extension AnyCodable: CustomStringConvertible {
    public var description: String {
        switch value {
        case let string as String:
            return "\"\(string)\""
        case let array as [Any]:
            let elements = array.map { "\(AnyCodable($0))" }.joined(separator: ", ")
            return "[\(elements)]"
        case let dictionary as [String: Any]:
            let pairs = dictionary.map { key, value in "\(key): \(AnyCodable(value))" }.joined(separator: ", ")
            return "{\(pairs)}"
        default:
            return "\(value)"
        }
    }
}
