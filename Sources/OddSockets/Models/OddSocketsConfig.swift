import Foundation

/// Configuration options for the OddSockets client.
public struct OddSocketsConfig {
    /// The OddSockets API key (required).
    public let apiKey: String
    
    /// The manager URL (optional, defaults to https://manager1.oddsockets.tyga.network).
    public let managerUrl: String
    
    /// The user identifier (optional, auto-generated if not provided).
    public let userId: String?
    
    /// Whether the client should auto-connect on creation (default: true).
    public let autoConnect: Bool
    
    /// The maximum number of reconnection attempts (default: 5).
    public let reconnectAttempts: Int
    
    /// The heartbeat interval in seconds (default: 30).
    public let heartbeatInterval: TimeInterval
    
    /// The request timeout in seconds (default: 10).
    public let timeout: TimeInterval
    
    /// Initializes a new OddSocketsConfig.
    /// - Parameters:
    ///   - apiKey: Your OddSockets API key
    ///   - managerUrl: Manager service URL
    ///   - userId: User identifier
    ///   - autoConnect: Auto-connect on creation
    ///   - reconnectAttempts: Max reconnection attempts
    ///   - heartbeatInterval: Heartbeat interval in seconds
    ///   - timeout: Request timeout in seconds
    public init(
        apiKey: String,
        managerUrl: String = "https://manager1.oddsockets.tyga.network",
        userId: String? = nil,
        autoConnect: Bool = true,
        reconnectAttempts: Int = 5,
        heartbeatInterval: TimeInterval = 30,
        timeout: TimeInterval = 10
    ) {
        self.apiKey = apiKey
        self.managerUrl = managerUrl
        self.userId = userId
        self.autoConnect = autoConnect
        self.reconnectAttempts = reconnectAttempts
        self.heartbeatInterval = heartbeatInterval
        self.timeout = timeout
    }
    
    /// Validates the configuration.
    /// - Throws: `OddSocketsError.invalidConfiguration` if configuration is invalid
    public func validate() throws {
        guard !apiKey.isEmpty else {
            throw OddSocketsError.invalidConfiguration("API key is required")
        }
        
        guard apiKey.hasPrefix("ak_") else {
            throw OddSocketsError.invalidConfiguration("Invalid API key format")
        }
        
        guard !managerUrl.isEmpty else {
            throw OddSocketsError.invalidConfiguration("Manager URL is required")
        }
        
        guard URL(string: managerUrl) != nil else {
            throw OddSocketsError.invalidConfiguration("Invalid manager URL format")
        }
        
        guard reconnectAttempts >= 0 else {
            throw OddSocketsError.invalidConfiguration("Reconnect attempts must be non-negative")
        }
        
        guard heartbeatInterval > 0 else {
            throw OddSocketsError.invalidConfiguration("Heartbeat interval must be positive")
        }
        
        guard timeout > 0 else {
            throw OddSocketsError.invalidConfiguration("Timeout must be positive")
        }
    }
}

/// Builder class for creating OddSocketsConfig instances using a fluent interface.
public class OddSocketsConfigBuilder {
    private var apiKey: String = ""
    private var managerUrl: String = "https://manager1.oddsockets.tyga.network"
    private var userId: String?
    private var autoConnect: Bool = true
    private var reconnectAttempts: Int = 5
    private var heartbeatInterval: TimeInterval = 30
    private var timeout: TimeInterval = 10
    
    /// Creates a new builder instance.
    public init() {}
    
    /// Sets the API key.
    /// - Parameter apiKey: The API key
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func apiKey(_ apiKey: String) -> OddSocketsConfigBuilder {
        self.apiKey = apiKey
        return self
    }
    
    /// Sets the manager URL.
    /// - Parameter managerUrl: The manager URL
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func managerUrl(_ managerUrl: String) -> OddSocketsConfigBuilder {
        self.managerUrl = managerUrl
        return self
    }
    
    /// Sets the user ID.
    /// - Parameter userId: The user ID
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func userId(_ userId: String) -> OddSocketsConfigBuilder {
        self.userId = userId
        return self
    }
    
    /// Sets whether to auto-connect.
    /// - Parameter autoConnect: Whether to auto-connect
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func autoConnect(_ autoConnect: Bool) -> OddSocketsConfigBuilder {
        self.autoConnect = autoConnect
        return self
    }
    
    /// Sets the reconnect attempts.
    /// - Parameter attempts: The number of reconnect attempts
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func reconnectAttempts(_ attempts: Int) -> OddSocketsConfigBuilder {
        self.reconnectAttempts = attempts
        return self
    }
    
    /// Sets the heartbeat interval.
    /// - Parameter interval: The heartbeat interval in seconds
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func heartbeatInterval(_ interval: TimeInterval) -> OddSocketsConfigBuilder {
        self.heartbeatInterval = interval
        return self
    }
    
    /// Sets the timeout.
    /// - Parameter timeout: The timeout in seconds
    /// - Returns: The builder instance for chaining
    @discardableResult
    public func timeout(_ timeout: TimeInterval) -> OddSocketsConfigBuilder {
        self.timeout = timeout
        return self
    }
    
    /// Builds the configuration.
    /// - Returns: The configured OddSocketsConfig instance
    /// - Throws: `OddSocketsError.invalidConfiguration` if configuration is invalid
    public func build() throws -> OddSocketsConfig {
        let config = OddSocketsConfig(
            apiKey: apiKey,
            managerUrl: managerUrl,
            userId: userId,
            autoConnect: autoConnect,
            reconnectAttempts: reconnectAttempts,
            heartbeatInterval: heartbeatInterval,
            timeout: timeout
        )
        
        try config.validate()
        return config
    }
}

// MARK: - Convenience Extensions

extension OddSocketsConfig {
    /// Creates a configuration with just an API key using default values.
    /// - Parameter apiKey: Your OddSockets API key
    /// - Returns: A configured OddSocketsConfig instance
    public static func `default`(apiKey: String) -> OddSocketsConfig {
        return OddSocketsConfig(apiKey: apiKey)
    }
}

extension OddSocketsConfigBuilder {
    /// Creates a builder with an API key pre-set.
    /// - Parameter apiKey: Your OddSockets API key
    /// - Returns: A builder instance with the API key set
    public static func with(apiKey: String) -> OddSocketsConfigBuilder {
        return OddSocketsConfigBuilder().apiKey(apiKey)
    }
}
