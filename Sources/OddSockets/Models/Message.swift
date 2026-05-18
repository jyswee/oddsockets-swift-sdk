import Foundation

/// Represents a message received from OddSockets.
public struct Message: Codable, Identifiable, Equatable {
    /// The unique message identifier.
    public let id: String
    
    /// The channel name.
    public let channel: String
    
    /// The message payload.
    public let data: AnyCodable?
    
    /// The message timestamp.
    public let timestamp: Date
    
    /// The sender's user ID.
    public let userId: String?
    
    /// Additional message metadata.
    public let metadata: [String: AnyCodable]?
    
    /// Initializes a new Message.
    /// - Parameters:
    ///   - id: Unique message identifier
    ///   - channel: Channel name
    ///   - data: Message payload
    ///   - timestamp: Message timestamp
    ///   - userId: Sender's user ID
    ///   - metadata: Additional metadata
    public init(
        id: String,
        channel: String,
        data: AnyCodable? = nil,
        timestamp: Date = Date(),
        userId: String? = nil,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.channel = channel
        self.data = data
        self.timestamp = timestamp
        self.userId = userId
        self.metadata = metadata
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case channel
        case data
        case timestamp
        case userId = "user_id"
        case metadata
    }
}

/// Represents presence information for a channel.
public struct PresenceInfo: Codable, Equatable {
    /// The channel name.
    public let channel: String
    
    /// The list of user IDs present in the channel.
    public let users: [String]
    
    /// The total number of users present.
    public let count: Int
    
    /// When the presence snapshot was taken.
    public let timestamp: Date
    
    /// Initializes a new PresenceInfo.
    /// - Parameters:
    ///   - channel: Channel name
    ///   - users: List of user IDs
    ///   - count: Total user count
    ///   - timestamp: Snapshot timestamp
    public init(
        channel: String,
        users: [String],
        count: Int,
        timestamp: Date = Date()
    ) {
        self.channel = channel
        self.users = users
        self.count = count
        self.timestamp = timestamp
    }
}

/// Represents the result of a publish operation.
public struct PublishResult: Codable, Equatable {
    /// The unique identifier of the published message.
    public let messageId: String
    
    /// When the message was published.
    public let timestamp: Date
    
    /// The channel the message was published to.
    public let channel: String
    
    /// Whether the publish was successful.
    public let success: Bool
    
    /// Initializes a new PublishResult.
    /// - Parameters:
    ///   - messageId: Published message ID
    ///   - timestamp: Publish timestamp
    ///   - channel: Channel name
    ///   - success: Success status
    public init(
        messageId: String,
        timestamp: Date = Date(),
        channel: String,
        success: Bool
    ) {
        self.messageId = messageId
        self.timestamp = timestamp
        self.channel = channel
        self.success = success
    }
    
    private enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case timestamp
        case channel
        case success
    }
}

/// Represents a message for bulk publishing.
public struct BulkMessage: Codable, Equatable {
    /// The channel name.
    public let channel: String
    
    /// The message payload.
    public let message: AnyCodable?
    
    /// The publish options for this message.
    public let options: PublishOptions?
    
    /// Initializes a new BulkMessage.
    /// - Parameters:
    ///   - channel: Channel name
    ///   - message: Message payload
    ///   - options: Publish options
    public init(
        channel: String,
        message: AnyCodable? = nil,
        options: PublishOptions? = nil
    ) {
        self.channel = channel
        self.message = message
        self.options = options
    }
}

/// Represents the result of a bulk publish operation.
public struct BulkResult: Codable, Equatable {
    /// Whether the publish was successful.
    public let success: Bool
    
    /// The publish result if successful.
    public let result: PublishResult?
    
    /// The error message if unsuccessful.
    public let error: String?
    
    /// Initializes a new BulkResult.
    /// - Parameters:
    ///   - success: Success status
    ///   - result: Publish result if successful
    ///   - error: Error message if unsuccessful
    public init(
        success: Bool,
        result: PublishResult? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.result = result
        self.error = error
    }
}

/// Options for channel subscription.
public struct SubscribeOptions: Codable, Equatable {
    /// Whether to enable presence tracking for the channel.
    public let enablePresence: Bool
    
    /// Whether to retain message history.
    public let retainHistory: Bool
    
    /// A filter expression for messages.
    public let filterExpression: String?
    
    /// Initializes new SubscribeOptions.
    /// - Parameters:
    ///   - enablePresence: Enable presence tracking
    ///   - retainHistory: Retain message history
    ///   - filterExpression: Filter expression
    public init(
        enablePresence: Bool = false,
        retainHistory: Bool = false,
        filterExpression: String? = nil
    ) {
        self.enablePresence = enablePresence
        self.retainHistory = retainHistory
        self.filterExpression = filterExpression
    }
    
    private enum CodingKeys: String, CodingKey {
        case enablePresence = "enable_presence"
        case retainHistory = "retain_history"
        case filterExpression = "filter_expression"
    }
}

/// Builder for SubscribeOptions.
public class SubscribeOptionsBuilder {
    private var enablePresence: Bool = false
    private var retainHistory: Bool = false
    private var filterExpression: String?
    
    /// Creates a new builder instance.
    public init() {}
    
    /// Enables presence tracking.
    /// - Parameter enable: Whether to enable presence tracking
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func enablePresence(_ enable: Bool = true) -> SubscribeOptionsBuilder {
        self.enablePresence = enable
        return self
    }
    
    /// Enables history retention.
    /// - Parameter retain: Whether to retain history
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func retainHistory(_ retain: Bool = true) -> SubscribeOptionsBuilder {
        self.retainHistory = retain
        return self
    }
    
    /// Sets a filter expression.
    /// - Parameter expression: The filter expression
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func filterExpression(_ expression: String) -> SubscribeOptionsBuilder {
        self.filterExpression = expression
        return self
    }
    
    /// Builds the options.
    /// - Returns: The configured SubscribeOptions instance
    public func build() -> SubscribeOptions {
        return SubscribeOptions(
            enablePresence: enablePresence,
            retainHistory: retainHistory,
            filterExpression: filterExpression
        )
    }
}

/// Options for message publishing.
public struct PublishOptions: Codable, Equatable {
    /// The time to live for the message in seconds.
    public let ttl: Int?
    
    /// Additional metadata for the message.
    public let metadata: [String: AnyCodable]?
    
    /// Whether the message should be stored in history.
    public let storeInHistory: Bool
    
    /// Initializes new PublishOptions.
    /// - Parameters:
    ///   - ttl: Time to live in seconds
    ///   - metadata: Additional metadata
    ///   - storeInHistory: Store in history
    public init(
        ttl: Int? = nil,
        metadata: [String: AnyCodable]? = nil,
        storeInHistory: Bool = false
    ) {
        self.ttl = ttl
        self.metadata = metadata
        self.storeInHistory = storeInHistory
    }
    
    private enum CodingKeys: String, CodingKey {
        case ttl
        case metadata
        case storeInHistory = "store_in_history"
    }
}

/// Builder for PublishOptions.
public class PublishOptionsBuilder {
    private var ttl: Int?
    private var metadata: [String: AnyCodable]?
    private var storeInHistory: Bool = false
    
    /// Creates a new builder instance.
    public init() {}
    
    /// Sets the time to live.
    /// - Parameter ttl: The TTL in seconds
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func ttl(_ ttl: Int) -> PublishOptionsBuilder {
        self.ttl = ttl
        return self
    }
    
    /// Sets metadata.
    /// - Parameter metadata: The metadata dictionary
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func metadata(_ metadata: [String: AnyCodable]) -> PublishOptionsBuilder {
        self.metadata = metadata
        return self
    }
    
    /// Adds a metadata entry.
    /// - Parameters:
    ///   - key: The metadata key
    ///   - value: The metadata value
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func metadata(key: String, value: AnyCodable) -> PublishOptionsBuilder {
        if self.metadata == nil {
            self.metadata = [:]
        }
        self.metadata?[key] = value
        return self
    }
    
    /// Sets whether to store in history.
    /// - Parameter store: Whether to store in history
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func storeInHistory(_ store: Bool = true) -> PublishOptionsBuilder {
        self.storeInHistory = store
        return self
    }
    
    /// Builds the options.
    /// - Returns: The configured PublishOptions instance
    public func build() -> PublishOptions {
        return PublishOptions(
            ttl: ttl,
            metadata: metadata,
            storeInHistory: storeInHistory
        )
    }
}

/// Options for retrieving message history.
public struct HistoryOptions: Codable, Equatable {
    /// The maximum number of messages to retrieve.
    public let limit: Int?
    
    /// The start time for the history query.
    public let start: Date?
    
    /// The end time for the history query.
    public let end: Date?
    
    /// Whether messages should be returned in reverse chronological order.
    public let reverse: Bool
    
    /// Initializes new HistoryOptions.
    /// - Parameters:
    ///   - limit: Maximum number of messages
    ///   - start: Start time
    ///   - end: End time
    ///   - reverse: Reverse order
    public init(
        limit: Int? = nil,
        start: Date? = nil,
        end: Date? = nil,
        reverse: Bool = false
    ) {
        self.limit = limit
        self.start = start
        self.end = end
        self.reverse = reverse
    }
}

/// Builder for HistoryOptions.
public class HistoryOptionsBuilder {
    private var limit: Int?
    private var start: Date?
    private var end: Date?
    private var reverse: Bool = false
    
    /// Creates a new builder instance.
    public init() {}
    
    /// Sets the limit.
    /// - Parameter limit: The maximum number of messages
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func limit(_ limit: Int) -> HistoryOptionsBuilder {
        self.limit = limit
        return self
    }
    
    /// Sets the start time.
    /// - Parameter start: The start time
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func start(_ start: Date) -> HistoryOptionsBuilder {
        self.start = start
        return self
    }
    
    /// Sets the end time.
    /// - Parameter end: The end time
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func end(_ end: Date) -> HistoryOptionsBuilder {
        self.end = end
        return self
    }
    
    /// Sets whether to reverse the order.
    /// - Parameter reverse: Whether to reverse the order
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func reverse(_ reverse: Bool = true) -> HistoryOptionsBuilder {
        self.reverse = reverse
        return self
    }
    
    /// Builds the options.
    /// - Returns: The configured HistoryOptions instance
    public func build() -> HistoryOptions {
        return HistoryOptions(
            limit: limit,
            start: start,
            end: end,
            reverse: reverse
        )
    }
}

// MARK: - Convenience Extensions

extension SubscribeOptions {
    /// Creates options with presence enabled.
    public static var withPresence: SubscribeOptions {
        return SubscribeOptions(enablePresence: true)
    }
    
    /// Creates options with history enabled.
    public static var withHistory: SubscribeOptions {
        return SubscribeOptions(retainHistory: true)
    }
    
    /// Creates options with both presence and history enabled.
    public static var withPresenceAndHistory: SubscribeOptions {
        return SubscribeOptions(enablePresence: true, retainHistory: true)
    }
}

extension PublishOptions {
    /// Creates options with history storage enabled.
    public static var withHistory: PublishOptions {
        return PublishOptions(storeInHistory: true)
    }
    
    /// Creates options with a TTL.
    /// - Parameter seconds: TTL in seconds
    /// - Returns: PublishOptions with TTL set
    public static func withTTL(_ seconds: Int) -> PublishOptions {
        return PublishOptions(ttl: seconds)
    }
}

extension HistoryOptions {
    /// Creates options with a limit.
    /// - Parameter count: Maximum number of messages
    /// - Returns: HistoryOptions with limit set
    public static func limit(_ count: Int) -> HistoryOptions {
        return HistoryOptions(limit: count)
    }
    
    /// Creates options for recent messages in reverse order.
    /// - Parameter count: Maximum number of messages
    /// - Returns: HistoryOptions for recent messages
    public static func recent(_ count: Int) -> HistoryOptions {
        return HistoryOptions(limit: count, reverse: true)
    }
}
