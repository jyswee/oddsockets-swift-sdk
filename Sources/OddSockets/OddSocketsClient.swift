import Foundation
import Combine
import SocketIO
import Logging

/// Main OddSockets client for real-time messaging.
///
/// This class provides the primary interface for connecting to OddSockets
/// and managing channels. It follows modern Swift patterns with async/await,
/// Combine publishers, and proper error handling.
@MainActor
public final class OddSocketsClient: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current connection state.
    @Published public private(set) var connectionState: ConnectionState = .disconnected
    
    /// Whether the client is connected.
    @Published public private(set) var isConnected: Bool = false
    
    /// The assigned worker information.
    @Published public private(set) var workerInfo: (workerId: String?, workerUrl: String?) = (nil, nil)
    
    // MARK: - Private Properties
    
    private let config: OddSocketsConfig
    private let logger: Logger
    private let urlSession: URLSession
    private var socketManager: SocketManager?
    private var socket: SocketIOClient?
    /// Dedicated queue Socket.IO callbacks are delivered on. Keeping socket I/O
    /// off the main queue prevents the MainActor executor from being starved in
    /// async command-line / server contexts.
    private let socketQueue = DispatchQueue(label: "com.oddsockets.socket", qos: .userInitiated)
    private var channels: [String: OddSocketsChannel] = [:]
    private var eventHandlers: [EventType: [(Any?) async -> Void]] = [:]
    /// Persistent raw event listeners keyed by wire event name. This is the
    /// public surface enhanced broadcasts (user_typing, reaction_added, ...) are
    /// delivered on, fed directly by the real Socket.IO transport.
    private var rawHandlers: [String: [(Any) -> Void]] = [:]
    /// One-shot raw event listeners (enhanced request/response) keyed by event name.
    private var rawOnceHandlers: [String: [(Any) -> Void]] = [:]
    private var reconnectAttempts: Int = 0
    private var heartbeatTimer: Timer?
    private var connectionTask: Task<Void, Never>?

    // Token-auth (minted-token) state. When a tokenProvider is configured the
    // client resolves a fresh token before every (re)connect and refreshes it
    // silently ahead of expiry.
    private var currentToken: String?
    private var tokenExpiresAtMs: Int?
    private var tokenRefreshTask: Task<Void, Never>?
    
    // Session stickiness properties
    private let clientIdentifier: String
    private var sessionInfo: [String: Any]?
    
    // MARK: - Subjects for Combine
    
    private let eventSubject = PassthroughSubject<(EventType, Any?), Never>()
    private let messageSubject = PassthroughSubject<Message, Never>()
    private let errorSubject = PassthroughSubject<OddSocketsError, Never>()
    
    // MARK: - Public Properties
    
    /// The user ID for this client.
    public var userId: String {
        return config.userId ?? "anonymous"
    }
    
    /// Publisher for all events.
    public var eventPublisher: AnyPublisher<(EventType, Any?), Never> {
        return eventSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for messages.
    public var messagePublisher: AnyPublisher<Message, Never> {
        return messageSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for errors.
    public var errorPublisher: AnyPublisher<OddSocketsError, Never> {
        return errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    /// Initializes a new OddSocketsClient.
    /// - Parameters:
    ///   - config: The configuration for the client
    ///   - logger: Optional logger instance
    ///   - urlSession: Optional URL session
    /// - Throws: `OddSocketsError.invalidConfiguration` if configuration is invalid
    public init(
        config: OddSocketsConfig,
        logger: Logger? = nil,
        urlSession: URLSession = .shared
    ) throws {
        try config.validate()

        // Generate user ID if not provided, resolving the final config once so
        // the immutable stored property is initialized a single time.
        var resolvedConfig = config
        if config.userId == nil {
            let generatedUserId = "user_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())"
            resolvedConfig = OddSocketsConfig(
                apiKey: config.apiKey,
                managerUrl: config.managerUrl,
                userId: generatedUserId,
                autoConnect: config.autoConnect,
                reconnectAttempts: config.reconnectAttempts,
                heartbeatInterval: config.heartbeatInterval,
                timeout: config.timeout,
                tokenProvider: config.tokenProvider,
                tokenRefreshLeadMs: config.tokenRefreshLeadMs
            )
        }

        self.config = resolvedConfig
        self.logger = logger ?? Logger(label: "com.oddsockets.client")
        self.urlSession = urlSession

        // Generate client identifier for session stickiness. Computed from
        // static helpers so no instance method is called before init completes.
        let resolvedUserId = resolvedConfig.userId ?? "anonymous"
        // In token mode there is no API key; seed the sticky-session hash with a
        // stable fallback so the identifier is still deterministic per user.
        let identifierSeed = resolvedConfig.apiKey.isEmpty ? "token-client" : resolvedConfig.apiKey
        self.clientIdentifier = "\(Self._hashString(identifierSeed))_\(resolvedUserId)"

        logger?.info("OddSockets client initialized for user: \(resolvedUserId)")
        
        // Auto-connect if requested
        if config.autoConnect {
            connectionTask = Task {
                do {
                    try await connect()
                } catch {
                    logger?.warning("Auto-connect failed: \(error)")
                    await emitEvent(.error, data: error)
                }
            }
        }
    }
    
    deinit {
        // Synchronous teardown only. Spawning a Task here would capture self
        // and outlive deinit, leaving a dangling reference that traps at
        // runtime ("deallocated with non-zero retain count"). The socket can
        // be closed directly without touching async, actor-isolated state.
        connectionTask?.cancel()
        heartbeatTimer?.invalidate()
        socket?.disconnect()
        socketManager?.disconnect()
    }
    
    // MARK: - Connection Management
    
    /// Connects to the OddSockets platform.
    /// - Throws: `OddSocketsError` if connection fails
    public func connect() async throws {
        guard connectionState != .connected else {
            logger.debug("Already connected")
            return
        }
        
        guard connectionState != .connecting else {
            logger.debug("Connection already in progress")
            return
        }
        
        connectionState = .connecting
        isConnected = false
        await emitEvent(.connected, data: ["userId": userId, "timestamp": Date()])
        
        logger.info("Connecting to OddSockets...")
        
        do {
            // Step 0: In token mode, resolve a fresh minted token before every
            // (re)connect. It is presented in place of an API key from here on.
            if isTokenMode {
                try await resolveToken()
            }

            // Step 1: Get worker assignment from manager
            try await getWorkerAssignment()

            // Step 2: Connect to assigned worker
            try await connectToWorker()

            connectionState = .connected
            isConnected = true
            reconnectAttempts = 0

            // Start heartbeat
            startHeartbeat()

            // Arm the silent pre-expiry token refresh.
            scheduleTokenRefresh()

            logger.info("Successfully connected to OddSockets")
            await emitEvent(.connected, data: ["userId": userId, "timestamp": Date()])
            
        } catch {
            connectionState = .failed
            isConnected = false
            logger.error("Connection failed: \(error)")
            
            let oddSocketsError = OddSocketsError.from(error)
            await emitEvent(.error, data: oddSocketsError)
            
            // Schedule reconnection if attempts remain
            if reconnectAttempts < config.reconnectAttempts {
                await scheduleReconnect()
            } else {
                await emitEvent(.maxReconnectAttemptsReached, data: ["attempts": reconnectAttempts])
            }
            
            throw oddSocketsError
        }
    }
    
    /// Disconnects from the OddSockets platform.
    public func disconnect() async {
        guard connectionState != .disconnected else {
            logger.debug("Already disconnected")
            return
        }
        
        logger.info("Disconnecting from OddSockets...")
        
        // Stop heartbeat
        stopHeartbeat()

        // Stop any pending token refresh
        tokenRefreshTask?.cancel()
        tokenRefreshTask = nil

        // Unsubscribe from all channels
        for channel in channels.values {
            await channel.unsubscribe()
        }
        
        // Close socket connection
        socket?.disconnect()
        socket = nil
        
        connectionState = .disconnected
        isConnected = false
        workerInfo = (nil, nil)
        
        logger.info("Disconnected from OddSockets")
        await emitEvent(.disconnected, data: ["userId": userId, "timestamp": Date()])
    }
    
    // MARK: - Channel Management
    
    /// Gets or creates a channel.
    /// - Parameter channelName: The channel name
    /// - Returns: A channel instance
    /// - Throws: `OddSocketsError.invalidChannelName` if channel name is invalid
    public func channel(_ channelName: String) throws -> OddSocketsChannel {
        guard !channelName.isEmpty else {
            throw OddSocketsError.invalidChannelName(channelName)
        }
        
        if let existingChannel = channels[channelName] {
            return existingChannel
        }
        
        let newChannel = OddSocketsChannel(name: channelName, client: self, logger: logger)
        channels[channelName] = newChannel
        return newChannel
    }
    
    // MARK: - Bulk Publishing
    
    /// Publishes multiple messages at once.
    /// - Parameter messages: The messages to publish
    /// - Returns: Results for each message
    /// - Throws: `OddSocketsError.connectionError` if not connected
    public func publishBulk(_ messages: [BulkMessage]) async throws -> [BulkResult] {
        guard isConnected else {
            throw OddSocketsError.connectionFailed("Not connected to OddSockets")
        }
        
        var results: [BulkResult] = []
        
        for bulkMessage in messages {
            do {
                guard !bulkMessage.channel.isEmpty else {
                    results.append(BulkResult(success: false, error: "Missing channel name"))
                    continue
                }
                
                let channel = try self.channel(bulkMessage.channel)
                let result = try await channel.publish(bulkMessage.message, options: bulkMessage.options)
                results.append(BulkResult(success: true, result: result))
                
            } catch {
                results.append(BulkResult(success: false, error: error.localizedDescription))
            }
        }
        
        return results
    }
    
    // MARK: - Event Handling
    
    /// Adds an event handler.
    /// - Parameters:
    ///   - eventType: The event type
    ///   - handler: The event handler
    public func on(_ eventType: EventType, handler: @escaping AsyncEventHandler) {
        if eventHandlers[eventType] == nil {
            eventHandlers[eventType] = []
        }
        eventHandlers[eventType]?.append(handler)
        logger.debug("Added event handler for \(eventType)")
    }
    
    /// Adds a synchronous event handler.
    /// - Parameters:
    ///   - eventType: The event type
    ///   - handler: The event handler
    public func on(_ eventType: EventType, handler: @escaping EventHandler) {
        // Type the wrapper explicitly so overload resolution routes to the
        // AsyncEventHandler variant above, not back into this method (which
        // would recurse infinitely).
        let asyncHandler: AsyncEventHandler = { data in handler(data) }
        on(eventType, handler: asyncHandler)
    }
    
    /// Removes event handlers.
    /// - Parameter eventType: The event type
    public func off(_ eventType: EventType) {
        eventHandlers.removeValue(forKey: eventType)
        logger.debug("Removed all handlers for \(eventType)")
    }

    // MARK: - Raw Event Surface (enhanced features)

    /// Emits a raw Socket.IO event to the worker.
    ///
    /// This is the send half of the enhanced (Slack-like) surface: the payload
    /// travels over the same live socket as core pub/sub, with no simulation.
    /// - Parameters:
    ///   - event: The wire event name (e.g. `start_typing`, `add_reaction`).
    ///   - data: The event payload.
    public func emit(_ event: String, data: [String: Any]) {
        guard let socket = socket, socket.status == .connected else {
            logger.warning("Cannot emit '\(event)': socket not connected")
            return
        }
        socket.emit(event, data)
    }

    /// Registers a persistent listener for a raw wire event.
    ///
    /// Enhanced broadcasts (`user_typing`, `reaction_added`, ...) are delivered
    /// here as they arrive from the worker.
    /// - Parameters:
    ///   - event: The wire event name.
    ///   - handler: Invoked with the decoded payload for every occurrence.
    public func on(_ event: String, handler: @escaping (Any) -> Void) {
        rawHandlers[event, default: []].append(handler)
    }

    /// Registers a one-shot listener for the next occurrence of a raw wire event.
    /// - Parameters:
    ///   - event: The wire event name.
    ///   - handler: Invoked once with the decoded payload, then removed.
    public func once(_ event: String, handler: @escaping (Any) -> Void) {
        rawOnceHandlers[event, default: []].append(handler)
    }

    /// Removes raw listeners for an event.
    ///
    /// Handler identity is not tracked, so this clears every persistent and
    /// one-shot listener registered for `event`.
    /// - Parameters:
    ///   - event: The wire event name.
    ///   - handler: Ignored; present for call-site symmetry.
    public func off(_ event: String, handler: @escaping (Any) -> Void) {
        rawHandlers[event] = nil
        rawOnceHandlers[event] = nil
    }

    /// Fans a decoded raw event out to registered listeners.
    private func dispatchRaw(_ event: String, _ payload: Any) {
        if let handlers = rawHandlers[event] {
            for handler in handlers { handler(payload) }
        }
        if let onceHandlers = rawOnceHandlers[event] {
            rawOnceHandlers[event] = nil
            for handler in onceHandlers { handler(payload) }
        }
    }

    // MARK: - Internal Methods
    
    internal func getSocket() -> SocketIOClient? {
        return socket
    }
    
    internal func emitEvent(_ eventType: EventType, data: Any?) async {
        // Emit to Combine publishers
        eventSubject.send((eventType, data))
        
        if let message = data as? Message {
            messageSubject.send(message)
        }
        
        if let error = data as? OddSocketsError {
            errorSubject.send(error)
        }
        
        // Emit to registered handlers
        if let handlers = eventHandlers[eventType] {
            for handler in handlers {
                await handler(data)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getWorkerAssignment() async throws {
        // Use the configured manager verbatim; never silently retarget production.
        let managerUrl = try ManagerDiscovery(configuredUrl: config.managerUrl).discoverManagerUrl()

        guard var urlComponents = URLComponents(string: "\(managerUrl)/api/cluster/select-worker") else {
            throw OddSocketsError.invalidConfiguration("Invalid managerUrl: \(managerUrl)")
        }
        // In token mode present the minted token instead of an API key.
        let authQueryItem = isTokenMode
            ? URLQueryItem(name: "token", value: currentToken)
            : URLQueryItem(name: "apiKey", value: config.apiKey)
        urlComponents.queryItems = [
            authQueryItem,
            URLQueryItem(name: "userId", value: userId),
            URLQueryItem(name: "clientIdentifier", value: clientIdentifier)
        ]

        guard let requestUrl = urlComponents.url else {
            throw OddSocketsError.invalidConfiguration("Invalid managerUrl: \(managerUrl)")
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        if isTokenMode, let token = currentToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        }
        request.setValue("OddSockets-Swift-SDK/0.1.0-beta.1", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = config.timeout
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OddSocketsError.networkError("Invalid response type")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw OddSocketsError.connectionError("Worker assignment failed with status \(httpResponse.statusCode)")
        }
        
        let assignment = try JSONDecoder().decode(WorkerAssignment.self, from: data)
        
        guard let workerUrl = assignment.url else {
            throw OddSocketsError.workerAssignmentFailed("Invalid worker assignment response")
        }
        
        workerInfo = (assignment.workerId, workerUrl)
        
        await emitEvent(.workerAssigned, data: [
            "workerId": assignment.workerId as Any,
            "workerUrl": workerUrl,
            "session": assignment.session as Any
        ])
    }
    
    private func connectToWorker() async throws {
        guard let workerUrl = workerInfo.workerUrl else {
            throw OddSocketsError.workerAssignmentFailed("No worker URL available")
        }
        
        guard let url = URL(string: workerUrl) else {
            throw OddSocketsError.workerAssignmentFailed("Invalid worker URL")
        }
        
        // Present the minted token on the handshake in token mode, otherwise
        // the API key.
        let authParams: [String: Any] = isTokenMode
            ? ["token": currentToken ?? "", "userId": userId]
            : ["apiKey": config.apiKey, "userId": userId]
        let manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .connectParams(authParams),
            .forceWebsockets(true),
            .handleQueue(socketQueue)
        ])

        socketManager = manager
        socket = manager.defaultSocket
        
        setupSocketEventHandlers()
        
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            
            socket?.on(clientEvent: .connect) { _, _ in
                if !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            
            socket?.on(clientEvent: .error) { data, _ in
                if !resumed {
                    resumed = true
                    let error = OddSocketsError.connectionError("Failed to connect to worker: \(data)")
                    continuation.resume(throwing: error)
                }
            }
            
            socket?.connect(timeoutAfter: config.timeout) {
                if !resumed {
                    resumed = true
                    continuation.resume(throwing: OddSocketsError.operationTimeout("Connection"))
                }
            }
        }
    }
    
    private func setupSocketEventHandlers() {
        guard let socket = socket else { return }

        // Fan every wire event out to the raw listener surface so enhanced
        // broadcasts (user_typing, reaction_added, ...) and enhanced
        // request/response replies reach registered on()/once() handlers.
        socket.onAny { [weak self] anyEvent in
            let payload: Any = anyEvent.items?.first ?? [String: Any]()
            Task { @MainActor in
                self?.dispatchRaw(anyEvent.event, payload)
            }
        }

        socket.on(clientEvent: .disconnect) { [weak self] data, _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.connectionState = .disconnected
                self.isConnected = false
                await self.emitEvent(.disconnected, data: data.first)
                
                // Auto-reconnect unless manually disconnected
                if let reason = data.first as? String, reason != "io client disconnect" {
                    await self.scheduleReconnect()
                }
            }
        }
        
        socket.on(clientEvent: .error) { [weak self] data, _ in
            Task { @MainActor in
                guard let self = self else { return }
                let error = OddSocketsError.connectionError("Socket error: \(data)")
                await self.emitEvent(.error, data: error)
            }
        }
        
        // Forward channel-related events to appropriate channels
        socket.on("message") { [weak self] data, _ in
            Task { @MainActor in
                await self?.handleChannelEvent("message", data: data)
            }
        }
        
        socket.on("subscribed") { [weak self] data, _ in
            Task { @MainActor in
                await self?.handleChannelEvent("subscribed", data: data)
            }
        }
        
        socket.on("unsubscribed") { [weak self] data, _ in
            Task { @MainActor in
                await self?.handleChannelEvent("unsubscribed", data: data)
            }
        }
        
        socket.on("published") { [weak self] data, _ in
            Task { @MainActor in
                await self?.handleChannelEvent("published", data: data)
            }
        }
        
        socket.on("presence") { [weak self] data, _ in
            Task { @MainActor in
                await self?.handleChannelEvent("presence", data: data)
            }
        }
        
        socket.on("presence_change") { [weak self] data, _ in
            Task { @MainActor in
                await self?.handleChannelEvent("presence_change", data: data)
            }
        }
        
        socket.on("history") { [weak self] data, _ in
            Task { @MainActor in
                await self?.handleChannelEvent("history", data: data)
            }
        }
    }
    
    private func handleChannelEvent(_ eventName: String, data: [Any]) async {
        guard let firstData = data.first,
              let jsonData = try? JSONSerialization.data(withJSONObject: firstData),
              let eventData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let channelName = eventData["channel"] as? String,
              let channel = channels[channelName] else {
            return
        }
        
        await channel.handleSocketEvent(eventName, data: eventData)
    }
    
    private func scheduleReconnect() async {
        guard connectionState != .connected else { return }
        
        connectionState = .reconnecting
        reconnectAttempts += 1
        
        let delay = min(1000 * pow(2.0, Double(reconnectAttempts - 1)), 30000) / 1000.0
        
        await emitEvent(.reconnected, data: [
            "attempt": reconnectAttempts,
            "maxAttempts": config.reconnectAttempts,
            "delay": delay
        ])
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        if connectionState == .reconnecting {
            do {
                try await connect()
            } catch {
                logger.warning("Reconnection attempt \(reconnectAttempts) failed: \(error)")
            }
        }
    }
    
    private func startHeartbeat() {
        guard config.heartbeatInterval > 0 else { return }
        
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: config.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.sendHeartbeat()
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() async {
        guard socket?.status == .connected else { return }
        
        logger.debug("Sending heartbeat")
        socket?.emit("ping", ["timestamp": Date().timeIntervalSince1970])
    }
    
    // MARK: - Token Auth (minted-token) Helpers

    /// Whether the client authenticates with minted tokens rather than an API key.
    private var isTokenMode: Bool {
        return config.tokenProvider != nil
    }

    /// Resolves a fresh token from the provider and records its expiry.
    ///
    /// Pure: it does not (re)arm the refresh loop, so it is safe to call from
    /// both the connect path and the refresh loop.
    private func resolveToken() async throws {
        guard let provider = config.tokenProvider else { return }

        let minted = try await provider()
        guard !minted.token.isEmpty else {
            throw OddSocketsError.authenticationError("Token provider returned an empty token")
        }

        currentToken = minted.token
        tokenExpiresAtMs = Self.expiryMs(from: minted)
    }

    /// Arms a single background loop that refreshes the token ahead of expiry.
    private func scheduleTokenRefresh() {
        tokenRefreshTask?.cancel()
        guard isTokenMode else { return }

        tokenRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                guard let expiresAt = self.tokenExpiresAtMs else { return }

                let nowMs = Int(Date().timeIntervalSince1970 * 1000)
                let delayMs = max(expiresAt - nowMs - self.config.tokenRefreshLeadMs, 0)
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                if Task.isCancelled { return }

                do {
                    try await self.resolveToken()
                    await self.emitEvent(.tokenRefreshed, data: ["expiresAt": self.tokenExpiresAtMs as Any])
                } catch {
                    self.logger.warning("Token refresh failed: \(error)")
                    return
                }
            }
        }
    }

    /// Derives an absolute expiry in epoch milliseconds from a minted token.
    ///
    /// Prefers explicit fields (`exp` epoch seconds, then `expiresAt` as epoch or
    /// ISO-8601), and finally falls back to decoding the JWT `exp` claim.
    private static func expiryMs(from token: OddSocketsToken) -> Int? {
        if let exp = token.exp {
            return exp * 1000
        }
        if let expiresAt = token.expiresAt {
            if let numeric = Double(expiresAt) {
                // < 1e12 → seconds, otherwise already milliseconds.
                return numeric < 1_000_000_000_000 ? Int(numeric * 1000) : Int(numeric)
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: expiresAt) {
                return Int(date.timeIntervalSince1970 * 1000)
            }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: expiresAt) {
                return Int(date.timeIntervalSince1970 * 1000)
            }
        }
        return expiryFromJwt(token.token)
    }

    /// Decodes the `exp` claim (epoch seconds) from a JWT and returns it in ms.
    private static func expiryFromJwt(_ jwt: String) -> Int? {
        let segments = jwt.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let exp = json["exp"] as? Int {
            return exp * 1000
        }
        if let exp = json["exp"] as? Double {
            return Int(exp * 1000)
        }
        return nil
    }

    // MARK: - Client Identifier Generation
    
    /// Simple hash function for API key
    private static func _hashString(_ str: String) -> String {
        var hash: Int = 0
        if str.isEmpty { return String(hash) }
        
        for char in str {
            let charValue = Int(char.asciiValue ?? 0)
            hash = ((hash << 5) &- hash) &+ charValue
            hash = hash & hash // Convert to 32-bit integer
        }
        
        return String(abs(hash), radix: 36)
    }
    
    // MARK: - Public Accessors
    
    /// Get client identifier used for session stickiness
    public func getClientIdentifier() -> String {
        return clientIdentifier
    }
    
    /// Get session information
    public func getSessionInfo() -> [String: Any]? {
        return sessionInfo
    }

    // MARK: - Enhanced Features

    /// The enhanced (Slack-like) feature surface for this client: threads,
    /// reactions, typing, presence, read receipts, and more, all over the same
    /// live socket.
    public private(set) lazy var enhanced: EnhancedFeatures = EnhancedFeatures(client: self)
}

// MARK: - Convenience Extensions

extension OddSocketsClient {
    /// Creates a client with default configuration.
    /// - Parameter apiKey: Your OddSockets API key
    /// - Returns: A configured OddSocketsClient instance
    /// - Throws: `OddSocketsError.invalidConfiguration` if configuration is invalid
    public static func `default`(apiKey: String) throws -> OddSocketsClient {
        let config = OddSocketsConfig.default(apiKey: apiKey)
        return try OddSocketsClient(config: config)
    }
}
