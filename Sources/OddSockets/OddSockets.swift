import Foundation

/// OddSockets Swift SDK
///
/// This module provides the main entry point for the OddSockets Swift SDK.
/// It exports all public types and provides convenience methods for common operations.

// MARK: - Public Exports

// Core Classes
public typealias OddSockets = OddSocketsClient

// Configuration
// (Already exported via OddSocketsConfig.swift)

// Models
// (Already exported via Message.swift and Types.swift)

// Errors
// (Already exported via OddSocketsError.swift)

// MARK: - Convenience Functions

/// Creates an OddSockets client with the specified API key.
/// - Parameter apiKey: Your OddSockets API key
/// - Returns: A configured OddSocketsClient instance
/// - Throws: `OddSocketsError.invalidConfiguration` if the API key is invalid
@MainActor
public func createClient(apiKey: String) throws -> OddSocketsClient {
    return try OddSocketsClient.default(apiKey: apiKey)
}

/// Creates an OddSockets client with custom configuration.
/// - Parameter config: The configuration to use
/// - Returns: A configured OddSocketsClient instance
/// - Throws: `OddSocketsError.invalidConfiguration` if the configuration is invalid
@MainActor
public func createClient(config: OddSocketsConfig) throws -> OddSocketsClient {
    return try OddSocketsClient(config: config)
}

// MARK: - Version Information

/// The current version of the OddSockets Swift SDK.
public let SDKVersion = "0.1.0-beta.1"

/// The SDK name.
public let SDKName = "OddSockets-Swift-SDK"

/// The user agent string for HTTP requests.
public let UserAgent = "\(SDKName)/\(SDKVersion)"

// MARK: - Global Configuration

/// Global configuration options for the SDK.
public struct GlobalConfig {
    /// The default log level for the SDK.
    public static var defaultLogLevel: Logger.Level = .info
    
    /// Whether to enable debug mode.
    public static var debugMode: Bool = false
    
    /// The default timeout for operations.
    public static var defaultTimeout: TimeInterval = 10.0
    
    /// The default heartbeat interval.
    public static var defaultHeartbeatInterval: TimeInterval = 30.0
}

// MARK: - Utility Extensions

extension OddSocketsConfigBuilder {
    /// Sets common development configuration.
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func development() -> OddSocketsConfigBuilder {
        return self
            .managerUrl("http://localhost:3001")
            .timeout(30)
            .heartbeatInterval(10)
    }
    
    /// Sets common production configuration.
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func production() -> OddSocketsConfigBuilder {
        return self
            .managerUrl("https://connect.oddsockets.tyga.network")
            .timeout(10)
            .heartbeatInterval(30)
    }
}

extension SubscribeOptionsBuilder {
    /// Sets options for a chat channel.
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func chatChannel() -> SubscribeOptionsBuilder {
        return self
            .enablePresence(true)
            .retainHistory(true)
    }
    
    /// Sets options for a notification channel.
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func notificationChannel() -> SubscribeOptionsBuilder {
        return self
            .enablePresence(false)
            .retainHistory(false)
    }
    
    /// Sets options for a data channel.
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func dataChannel() -> SubscribeOptionsBuilder {
        return self
            .enablePresence(false)
            .retainHistory(true)
    }
}

extension PublishOptionsBuilder {
    /// Sets options for a chat message.
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func chatMessage() -> PublishOptionsBuilder {
        return self
            .storeInHistory(true)
            .metadata(key: "type", value: AnyCodable("chat"))
    }
    
    /// Sets options for a notification message.
    /// - Parameters:
    ///   - priority: The notification priority
    ///   - ttl: Time to live in seconds
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func notification(priority: String = "normal", ttl: Int = 3600) -> PublishOptionsBuilder {
        return self
            .ttl(ttl)
            .metadata(key: "type", value: AnyCodable("notification"))
            .metadata(key: "priority", value: AnyCodable(priority))
    }
    
    /// Sets options for a system message.
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func systemMessage() -> PublishOptionsBuilder {
        return self
            .storeInHistory(true)
            .metadata(key: "type", value: AnyCodable("system"))
            .metadata(key: "priority", value: AnyCodable("high"))
    }
}

// MARK: - Common Message Types

/// A chat message structure.
public struct ChatMessage: Codable {
    public let text: String
    public let username: String
    public let timestamp: Date
    public let messageType: String
    
    public init(text: String, username: String, messageType: String = "chat") {
        self.text = text
        self.username = username
        self.timestamp = Date()
        self.messageType = messageType
    }
}

/// A notification message structure.
public struct NotificationMessage: Codable {
    public let title: String
    public let body: String
    public let category: String
    public let priority: String
    public let timestamp: Date
    public let data: [String: AnyCodable]?
    
    public init(
        title: String,
        body: String,
        category: String = "general",
        priority: String = "normal",
        data: [String: AnyCodable]? = nil
    ) {
        self.title = title
        self.body = body
        self.category = category
        self.priority = priority
        self.timestamp = Date()
        self.data = data
    }
}

/// A system message structure.
public struct SystemMessage: Codable {
    public let event: String
    public let description: String
    public let timestamp: Date
    public let metadata: [String: AnyCodable]?
    
    public init(
        event: String,
        description: String,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.event = event
        self.description = description
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Helper Functions

/// Converts a Codable object to AnyCodable.
/// - Parameter value: The Codable value to convert
/// - Returns: An AnyCodable wrapper
public func toCodable<T: Codable>(_ value: T) -> AnyCodable {
    return AnyCodable(value)
}

/// Creates a bulk message for publishing.
/// - Parameters:
///   - channel: The channel name
///   - message: The message data
///   - options: Optional publish options
/// - Returns: A BulkMessage instance
public func bulkMessage(
    channel: String,
    message: AnyCodable?,
    options: PublishOptions? = nil
) -> BulkMessage {
    return BulkMessage(channel: channel, message: message, options: options)
}

/// Creates multiple bulk messages for the same channel.
/// - Parameters:
///   - channel: The channel name
///   - messages: The messages to send
///   - options: Optional publish options
/// - Returns: An array of BulkMessage instances
public func bulkMessages(
    channel: String,
    messages: [AnyCodable?],
    options: PublishOptions? = nil
) -> [BulkMessage] {
    return messages.map { message in
        BulkMessage(channel: channel, message: message, options: options)
    }
}

// MARK: - Logging Helpers

import Logging

/// Creates a logger for OddSockets components.
/// - Parameter label: The logger label
/// - Returns: A configured Logger instance
public func createLogger(label: String) -> Logger {
    var logger = Logger(label: label)
    logger.logLevel = GlobalConfig.defaultLogLevel
    return logger
}

/// Sets the global log level for all OddSockets loggers.
/// - Parameter level: The log level to set
public func setGlobalLogLevel(_ level: Logger.Level) {
    GlobalConfig.defaultLogLevel = level
}

// MARK: - Debug Helpers

#if DEBUG
/// Debug helper to print SDK information.
public func printSDKInfo() {
    print("🚀 \(SDKName) v\(SDKVersion)")
    print("📱 Platform: iOS/macOS/tvOS/watchOS")
    print("🔧 Debug Mode: \(GlobalConfig.debugMode)")
    print("📊 Log Level: \(GlobalConfig.defaultLogLevel)")
}

/// Debug helper to validate configuration.
/// - Parameter config: The configuration to validate
public func validateConfig(_ config: OddSocketsConfig) {
    do {
        try config.validate()
        print("✅ Configuration is valid")
    } catch {
        print("❌ Configuration error: \(error)")
    }
}
#endif
