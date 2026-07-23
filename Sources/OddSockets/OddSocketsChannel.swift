import Foundation
import Combine
import Logging

/// Channel class for managing real-time messaging.
///
/// This class provides channel-specific functionality for subscribing,
/// publishing, and managing messages. It follows modern Swift patterns
/// with async/await, Combine publishers, and proper error handling.
@MainActor
public final class OddSocketsChannel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether the channel is subscribed.
    @Published public private(set) var isSubscribed: Bool = false
    
    /// The current subscription options.
    @Published public private(set) var subscriptionOptions: SubscribeOptions?
    
    /// The message history for this channel.
    @Published public private(set) var messageHistory: [Message] = []
    
    /// The current presence information.
    @Published public private(set) var presenceInfo: PresenceInfo?
    
    // MARK: - Private Properties
    
    private let name: String
    private weak var client: OddSocketsClient?
    private let logger: Logger
    private var messageHandler: AsyncMessageHandler?
    private var eventHandlers: [EventType: [(Any?) async -> Void]] = [:]
    private let operationQueue = DispatchQueue(label: "com.oddsockets.channel", qos: .userInitiated)
    
    // MARK: - Subjects for Combine
    
    private let messageSubject = PassthroughSubject<Message, Never>()
    private let presenceSubject = PassthroughSubject<PresenceInfo, Never>()
    private let eventSubject = PassthroughSubject<(EventType, Any?), Never>()
    
    // MARK: - Public Properties
    
    /// The channel name.
    public var channelName: String {
        return name
    }
    
    /// Publisher for messages received on this channel.
    public var messagePublisher: AnyPublisher<Message, Never> {
        return messageSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for presence updates on this channel.
    public var presencePublisher: AnyPublisher<PresenceInfo, Never> {
        return presenceSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for all events on this channel.
    public var eventPublisher: AnyPublisher<(EventType, Any?), Never> {
        return eventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    /// Initializes a new OddSocketsChannel.
    /// - Parameters:
    ///   - name: The channel name
    ///   - client: The OddSockets client
    ///   - logger: The logger instance
    internal init(name: String, client: OddSocketsClient, logger: Logger) {
        self.name = name
        self.client = client
        self.logger = logger
        
        logger.debug("Channel '\(name)' initialized")
    }
    
    // MARK: - Subscription Management
    
    /// Subscribes to channel messages.
    /// - Parameters:
    ///   - handler: The message handler
    ///   - options: Optional subscription options
    /// - Throws: `OddSocketsError` if subscription fails
    public func subscribe(
        handler: @escaping AsyncMessageHandler,
        options: SubscribeOptions = SubscribeOptions()
    ) async throws {
        guard let client = client else {
            throw OddSocketsError.channelError("Client not available", channel: name)
        }
        guard client.isConnected else {
            throw OddSocketsError.connectionFailed("Not connected to OddSockets")
        }
        guard !isSubscribed else {
            logger.warning("Channel '\(name)' already subscribed")
            return
        }
        logger.info("Subscribing to channel: \(name)")
        
        do {
            guard let socket = client.getSocket() else {
                throw OddSocketsError.connectionFailed("Socket not available")
            }
            
            // Store handler and options
            messageHandler = handler
            subscriptionOptions = options
            
            // Send subscription request
            let subscribeData: [String: Any] = [
                "channel": name,
                "options": [
                    "enable_presence": options.enablePresence,
                    "retain_history": options.retainHistory,
                    "filter_expression": options.filterExpression as Any
                ]
            ]
            
            socket.emit("subscribe", subscribeData)

            isSubscribed = true

            // If presence is enabled, add current user
            if options.enablePresence {
                await updatePresence(addUser: client.userId)
            }

            logger.info("Subscribed to channel: \(name)")
            
        } catch {
            logger.error("Subscription failed for channel '\(name)': \(error)")
            throw OddSocketsError.channelError(
                "Failed to subscribe to channel '\(name)'",
                channel: name,
                code: ErrorCodes.channelAccessDenied
            )
        }
    }
    
    /// Subscribes to channel messages with a synchronous handler.
    /// - Parameters:
    ///   - handler: The message handler
    ///   - options: Optional subscription options
    /// - Throws: `OddSocketsError` if subscription fails
    public func subscribe(
        handler: @escaping MessageHandler,
        options: SubscribeOptions = SubscribeOptions()
    ) async throws {
        // Wrap in an explicitly async closure so overload resolution routes to
        // the AsyncMessageHandler variant below, not back into this method.
        let asyncHandler: AsyncMessageHandler = { message in handler(message) }
        try await subscribe(handler: asyncHandler, options: options)
    }
    
    /// Unsubscribes from channel messages.
    /// - Throws: `OddSocketsError` if unsubscription fails
    public func unsubscribe() async {
        guard isSubscribed else {
            logger.debug("Channel '\(name)' not subscribed")
            return
        }
        
        logger.info("Unsubscribing from channel: \(name)")
        
        do {
            if let socket = client?.getSocket() {
                socket.emit("unsubscribe", ["channel": name])
            }
            
            // Simulate network delay
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            isSubscribed = false
            messageHandler = nil
            subscriptionOptions = nil
            
            // Remove from presence
            if let client = client {
                await updatePresence(removeUser: client.userId)
            }
            
            logger.info("Unsubscribed from channel: \(name)")
            
        } catch {
            logger.error("Unsubscription failed for channel '\(name)': \(error)")
        }
    }
    
    // MARK: - Message Publishing
    
    /// Publishes a message to the channel.
    /// - Parameters:
    ///   - message: The message data to publish
    ///   - options: Optional publish options
    /// - Returns: The publish result
    /// - Throws: `OddSocketsError` if publishing fails
    public func publish(
        _ message: AnyCodable?,
        options: PublishOptions? = nil
    ) async throws -> PublishResult {
        guard let client = client else {
            throw OddSocketsError.channelError("Client not available", channel: name)
        }
        
        guard client.isConnected else {
            throw OddSocketsError.connectionFailed("Not connected to OddSockets")
        }
        
        do {
            // Validate message size before publishing
            try MessageSizeValidator.validateMessageSize(message?.value)
            
            let messageId = "msg_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
            let timestamp = Date()
            
            // Create message object
            let messageObj = Message(
                id: messageId,
                channel: name,
                data: message,
                timestamp: timestamp,
                userId: client.userId,
                metadata: options?.metadata
            )
            
            guard let socket = client.getSocket() else {
                throw OddSocketsError.connectionFailed("Socket not available")
            }
            
            // Send publish request
            let publishData: [String: Any] = [
                "channel": name,
                "message": message?.value as Any,
                "options": [
                    "ttl": options?.ttl as Any,
                    "metadata": options?.metadata?.mapValues { $0.value } as Any,
                    "store_in_history": options?.storeInHistory ?? false
                ]
            ]
            
            // Publish over the real transport. Delivery back to subscribers
            // (including this client) happens only via the worker's 'message'
            // broadcast, never a local echo, so two-client fan-out is genuine.
            socket.emit("publish", publishData)

            // Store in local history if requested.
            if options?.storeInHistory == true || subscriptionOptions?.retainHistory == true {
                messageHistory.append(messageObj)

                // Keep only last 100 messages
                if messageHistory.count > 100 {
                    messageHistory.removeFirst(messageHistory.count - 100)
                }
            }

            logger.debug("Published message to channel '\(name)': \(message?.description ?? "nil")")
            
            return PublishResult(
                messageId: messageId,
                timestamp: timestamp,
                channel: name,
                success: true
            )
            
        } catch {
            logger.error("Failed to publish message to channel '\(name)': \(error)")
            throw OddSocketsError.messageError(
                "Failed to publish message to channel '\(name)'",
                messageId: nil,
                code: ErrorCodes.messageDeliveryFailed
            )
        }
    }
    
    // MARK: - History Management
    
    /// Gets message history for the channel.
    /// - Parameter options: Optional history options
    /// - Returns: The message history
    /// - Throws: `OddSocketsError` if retrieval fails
    public func getHistory(options: HistoryOptions? = nil) async throws -> [Message] {
        guard let client = client else {
            throw OddSocketsError.channelError("Client not available", channel: name)
        }
        
        guard client.isConnected else {
            throw OddSocketsError.connectionFailed("Not connected to OddSockets")
        }
        
        do {
            // Simulate API call delay
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            var messages = messageHistory
            
            // Filter by time range if specified
            if let start = options?.start {
                messages = messages.filter { $0.timestamp >= start }
            }
            
            if let end = options?.end {
                messages = messages.filter { $0.timestamp <= end }
            }
            
            // Sort messages
            if options?.reverse == true {
                messages.sort { $0.timestamp > $1.timestamp }
            } else {
                messages.sort { $0.timestamp < $1.timestamp }
            }
            
            // Apply limit
            if let limit = options?.limit, limit > 0 {
                messages = Array(messages.prefix(limit))
            }
            
            logger.debug("Retrieved \(messages.count) messages from channel '\(name)' history")
            return messages
            
        } catch {
            logger.error("Failed to get history for channel '\(name)': \(error)")
            throw OddSocketsError.channelError(
                "Failed to get history for channel '\(name)'",
                channel: name
            )
        }
    }
    
    // MARK: - Presence Management
    
    /// Gets presence information for the channel.
    /// - Returns: The presence information
    /// - Throws: `OddSocketsError` if retrieval fails
    public func getPresence() async throws -> PresenceInfo {
        guard let client = client else {
            throw OddSocketsError.channelError("Client not available", channel: name)
        }
        
        guard client.isConnected else {
            throw OddSocketsError.connectionFailed("Not connected to OddSockets")
        }
        
        do {
            // Simulate API call delay
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            
            let users = presenceInfo?.users ?? [client.userId]
            let presence = PresenceInfo(
                channel: name,
                users: users,
                count: users.count,
                timestamp: Date()
            )
            
            presenceInfo = presence
            
            logger.debug("Retrieved presence for channel '\(name)': \(presence.count) users")
            return presence
            
        } catch {
            logger.error("Failed to get presence for channel '\(name)': \(error)")
            throw OddSocketsError.channelError(
                "Failed to get presence for channel '\(name)'",
                channel: name
            )
        }
    }
    
    // MARK: - Event Handling
    
    /// Adds an event handler for channel events.
    /// - Parameters:
    ///   - eventType: The event type
    ///   - handler: The event handler
    public func on(_ eventType: EventType, handler: @escaping AsyncEventHandler) {
        if eventHandlers[eventType] == nil {
            eventHandlers[eventType] = []
        }
        eventHandlers[eventType]?.append(handler)
        logger.debug("Added event handler for \(eventType) on channel '\(name)'")
    }
    
    /// Adds a synchronous event handler for channel events.
    /// - Parameters:
    ///   - eventType: The event type
    ///   - handler: The event handler
    public func on(_ eventType: EventType, handler: @escaping EventHandler) {
        on(eventType) { data in
            handler(data)
        }
    }
    
    /// Removes event handlers for channel events.
    /// - Parameter eventType: The event type
    public func off(_ eventType: EventType) {
        eventHandlers.removeValue(forKey: eventType)
        logger.debug("Removed all handlers for \(eventType) on channel '\(name)'")
    }
    
    // MARK: - Internal Methods
    
    internal func handleSocketEvent(_ eventName: String, data: [String: Any]) async {
        switch eventName {
        case "message":
            await handleMessage(data: data)
        case "subscribed":
            await handleSubscribed(data: data)
        case "unsubscribed":
            await handleUnsubscribed(data: data)
        case "published":
            await handlePublished(data: data)
        case "presence", "presence_change":
            await handlePresence(data: data)
        case "history":
            await handleHistory(data: data)
        default:
            logger.debug("Unknown socket event: \(eventName)")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleMessage(data: [String: Any]) async {
        // Map the worker's broadcast envelope onto a Message. The wire shape is
        //   { id, channel, message: <payload>, publisher: { userId }, timestamp: ISO8601, metadata }
        // which does not line up with Message's synthesized Codable, so decode by hand.
        let id = (data["id"] as? String) ?? (data["messageId"] as? String) ?? UUID().uuidString
        let channelName = (data["channel"] as? String) ?? name

        let payload = data["message"] ?? data["data"]
        let messageData: AnyCodable? = payload.map { AnyCodable($0) }

        var userId = data["userId"] as? String ?? data["user_id"] as? String
        if userId == nil, let publisher = data["publisher"] as? [String: Any] {
            userId = publisher["userId"] as? String
        }

        let timestamp = Self.parseTimestamp(data["timestamp"]) ?? Date()

        var metadata: [String: AnyCodable]?
        if let rawMeta = data["metadata"] as? [String: Any], !rawMeta.isEmpty {
            metadata = rawMeta.mapValues { AnyCodable($0) }
        }

        let message = Message(
            id: id,
            channel: channelName,
            data: messageData,
            timestamp: timestamp,
            userId: userId,
            metadata: metadata
        )
        await deliverMessage(message)
    }

    /// Parses a timestamp that may arrive as an ISO8601 string, epoch seconds,
    /// or epoch milliseconds.
    private static func parseTimestamp(_ raw: Any?) -> Date? {
        if let str = raw as? String {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: str) { return date }
            if let seconds = Double(str) {
                return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
            }
            return nil
        }
        if let number = raw as? Double {
            return Date(timeIntervalSince1970: number > 1_000_000_000_000 ? number / 1000 : number)
        }
        if let number = raw as? Int {
            let seconds = Double(number)
            return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
        }
        return nil
    }
    
    private func handleSubscribed(data: [String: Any]) async {
        await emitEvent(.connected, data: data)
    }
    
    private func handleUnsubscribed(data: [String: Any]) async {
        await emitEvent(.disconnected, data: data)
    }
    
    private func handlePublished(data: [String: Any]) async {
        await emitEvent(.message, data: data)
    }
    
    private func handlePresence(data: [String: Any]) async {
        // The worker sends either a full snapshot ({ channel, users, count }) or an
        // incremental presence_change ({ channel, action, user, occupancy }). Handle
        // both without treating the incremental shape as an error.
        let channelName = (data["channel"] as? String) ?? name

        var users = presenceInfo?.users ?? []
        if let snapshotUsers = data["users"] as? [String] {
            users = snapshotUsers
        } else if let action = data["action"] as? String,
                  let user = data["user"] as? [String: Any],
                  let userId = user["userId"] as? String {
            switch action {
            case "join":
                if !users.contains(userId) { users.append(userId) }
            case "leave":
                users.removeAll { $0 == userId }
            default:
                break
            }
        }

        let count = (data["count"] as? Int) ?? (data["occupancy"] as? Int) ?? users.count
        let presence = PresenceInfo(channel: channelName, users: users, count: count, timestamp: Date())
        presenceInfo = presence
        presenceSubject.send(presence)
        await emitEvent(.presence, data: presence)
    }
    
    private func handleHistory(data: [String: Any]) async {
        // Handle history response if needed
    }
    
    private func deliverMessage(_ message: Message) async {
        guard let messageHandler = messageHandler else { return }
        
        do {
            // Apply filter if specified
            if let filterExpression = subscriptionOptions?.filterExpression {
                if !evaluateFilter(message: message, expression: filterExpression) {
                    return
                }
            }
            
            // Emit to Combine publisher
            messageSubject.send(message)
            
            // Call handler
            await messageHandler(message)
            
        } catch {
            logger.error("Error delivering message to handler for channel '\(name)': \(error)")
        }
    }
    
    private func evaluateFilter(message: Message, expression: String) -> Bool {
        do {
            // Simple filter evaluation (in real SDK, this would be more sophisticated)
            let encoder = JSONEncoder()
            let messageData = try encoder.encode(message.data)
            let messageString = String(data: messageData, encoding: .utf8) ?? ""
            return messageString.localizedCaseInsensitiveContains(expression)
        } catch {
            return true // If filter evaluation fails, pass the message
        }
    }
    
    private func updatePresence(addUser: String? = nil, removeUser: String? = nil) async {
        var users = presenceInfo?.users ?? []
        
        if let addUser = addUser, !users.contains(addUser) {
            users.append(addUser)
        }
        
        if let removeUser = removeUser {
            users.removeAll { $0 == removeUser }
        }
        
        let newPresence = PresenceInfo(
            channel: name,
            users: users,
            count: users.count,
            timestamp: Date()
        )
        
        presenceInfo = newPresence
        presenceSubject.send(newPresence)
        await emitEvent(.presence, data: newPresence)
    }
    
    private func emitEvent(_ eventType: EventType, data: Any?) async {
        // Emit to Combine publisher
        eventSubject.send((eventType, data))
        
        // Emit to registered handlers
        if let handlers = eventHandlers[eventType] {
            for handler in handlers {
                await handler(data)
            }
        }
    }
}

// MARK: - CustomStringConvertible

extension OddSocketsChannel: CustomStringConvertible {
    public var description: String {
        return "Channel(name='\(name)', subscribed=\(isSubscribed), history=\(messageHistory.count))"
    }
}

// MARK: - Convenience Extensions

extension OddSocketsChannel {
    /// Publishes a string message.
    /// - Parameters:
    ///   - text: The text message
    ///   - options: Optional publish options
    /// - Returns: The publish result
    /// - Throws: `OddSocketsError` if publishing fails
    public func publish(text: String, options: PublishOptions? = nil) async throws -> PublishResult {
        return try await publish(AnyCodable(text), options: options)
    }
    
    /// Publishes a dictionary message.
    /// - Parameters:
    ///   - dictionary: The dictionary message
    ///   - options: Optional publish options
    /// - Returns: The publish result
    /// - Throws: `OddSocketsError` if publishing fails
    public func publish(dictionary: [String: Any], options: PublishOptions? = nil) async throws -> PublishResult {
        return try await publish(AnyCodable(dictionary), options: options)
    }
    
    /// Publishes an array message.
    /// - Parameters:
    ///   - array: The array message
    ///   - options: Optional publish options
    /// - Returns: The publish result
    /// - Throws: `OddSocketsError` if publishing fails
    public func publish(array: [Any], options: PublishOptions? = nil) async throws -> PublishResult {
        return try await publish(AnyCodable(array), options: options)
    }
}
