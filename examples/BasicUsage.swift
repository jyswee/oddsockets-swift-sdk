import Foundation
import OddSockets
import Combine

/// Basic usage examples for the OddSockets Swift SDK.
///
/// This file demonstrates common patterns and use cases for real-time messaging
/// with OddSockets, including async/await patterns, Combine integration,
/// and SwiftUI compatibility.

// MARK: - Basic Connection Example

@MainActor
class BasicExample {
    private var client: OddSocketsClient?
    private var cancellables = Set<AnyCancellable>()
    
    func basicConnectionExample() async {
        do {
            // Create client with API key
            let config = try OddSocketsConfigBuilder()
                .apiKey("ak_your_api_key_here")
                .userId("user123")
                .build()
            
            client = try OddSocketsClient(config: config)
            
            // Connect to OddSockets
            try await client?.connect()
            print("✅ Connected to OddSockets!")
            
        } catch {
            print("❌ Connection failed: \(error)")
        }
    }
    
    func disconnect() async {
        await client?.disconnect()
        print("👋 Disconnected from OddSockets")
    }
}

// MARK: - Channel Subscription Example

@MainActor
class ChannelExample {
    private var client: OddSocketsClient?
    private var channel: OddSocketsChannel?
    private var cancellables = Set<AnyCancellable>()
    
    func channelSubscriptionExample() async {
        do {
            // Create and connect client
            client = try OddSocketsClient.default(apiKey: "ak_your_api_key_here")
            try await client?.connect()
            
            // Get channel
            channel = try client?.channel("chat-room")
            
            // Subscribe with async handler
            try await channel?.subscribe { message in
                print("📨 Received message: \(message.data?.description ?? "nil")")
                print("   From: \(message.userId ?? "unknown")")
                print("   Channel: \(message.channel)")
                print("   Time: \(message.timestamp)")
            }
            
            print("✅ Subscribed to chat-room channel")
            
        } catch {
            print("❌ Subscription failed: \(error)")
        }
    }
    
    func publishMessage() async {
        do {
            let chatMessage = ChatMessage(
                text: "Hello from Swift!",
                username: "SwiftUser"
            )
            
            let result = try await channel?.publish(toCodable(chatMessage))
            print("✅ Message published: \(result?.messageId ?? "unknown")")
            
        } catch {
            print("❌ Publishing failed: \(error)")
        }
    }
}

// MARK: - Combine Integration Example

@MainActor
class CombineExample: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    
    private var client: OddSocketsClient?
    private var channel: OddSocketsChannel?
    private var cancellables = Set<AnyCancellable>()
    
    func setupCombineIntegration() async {
        do {
            client = try OddSocketsClient.default(apiKey: "ak_your_api_key_here")
            
            // Observe connection state
            client?.$connectionState
                .receive(on: DispatchQueue.main)
                .assign(to: \.connectionState, on: self)
                .store(in: &cancellables)
            
            client?.$isConnected
                .receive(on: DispatchQueue.main)
                .assign(to: \.isConnected, on: self)
                .store(in: &cancellables)
            
            // Subscribe to messages
            client?.messagePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    self?.messages.append(message)
                }
                .store(in: &cancellables)
            
            // Connect
            try await client?.connect()
            
            // Subscribe to channel
            channel = try client?.channel("updates")
            try await channel?.subscribe { _ in
                // Messages are handled by Combine publisher above
            }
            
        } catch {
            print("❌ Setup failed: \(error)")
        }
    }
}

// MARK: - SwiftUI Integration Example

import SwiftUI

struct ChatView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            // Connection status
            HStack {
                Circle()
                    .fill(chatManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(chatManager.connectionState.description)
                    .font(.caption)
                Spacer()
            }
            .padding()
            
            // Messages list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(chatManager.messages) { message in
                        MessageRow(message: message)
                    }
                }
            }
            
            // Message input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    Task {
                        await chatManager.sendMessage(messageText)
                        messageText = ""
                    }
                }
                .disabled(messageText.isEmpty || !chatManager.isConnected)
            }
            .padding()
        }
        .task {
            await chatManager.connect()
        }
    }
}

struct MessageRow: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.userId ?? "Unknown")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.data?.stringValue ?? "No content")
                .font(.body)
        }
        .padding(.horizontal)
    }
}

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    
    private var client: OddSocketsClient?
    private var channel: OddSocketsChannel?
    private var cancellables = Set<AnyCancellable>()
    
    func connect() async {
        do {
            let config = try OddSocketsConfigBuilder()
                .apiKey("ak_your_api_key_here")
                .userId("swift_user_\(UUID().uuidString.prefix(8))")
                .build()
            
            client = try OddSocketsClient(config: config)
            
            // Setup Combine bindings
            client?.$isConnected
                .receive(on: DispatchQueue.main)
                .assign(to: \.isConnected, on: self)
                .store(in: &cancellables)
            
            client?.$connectionState
                .receive(on: DispatchQueue.main)
                .assign(to: \.connectionState, on: self)
                .store(in: &cancellables)
            
            // Connect and subscribe
            try await client?.connect()
            
            channel = try client?.channel("chat")
            
            // Subscribe with Combine
            channel?.messagePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    self?.messages.append(message)
                }
                .store(in: &cancellables)
            
            try await channel?.subscribe { _ in
                // Messages handled by Combine publisher
            }
            
        } catch {
            print("❌ Connection failed: \(error)")
        }
    }
    
    func sendMessage(_ text: String) async {
        guard !text.isEmpty else { return }
        
        do {
            let chatMessage = ChatMessage(
                text: text,
                username: client?.userId ?? "Anonymous"
            )
            
            _ = try await channel?.publish(toCodable(chatMessage))
            
        } catch {
            print("❌ Failed to send message: \(error)")
        }
    }
}

// MARK: - Advanced Features Example

@MainActor
class AdvancedExample {
    private var client: OddSocketsClient?
    private var cancellables = Set<AnyCancellable>()
    
    func advancedFeaturesExample() async {
        do {
            // Create client with custom configuration
            let config = try OddSocketsConfigBuilder()
                .apiKey("ak_your_api_key_here")
                .userId("advanced_user")
                .managerUrl("https://connect.oddsockets.tyga.network")
                .timeout(15)
                .heartbeatInterval(20)
                .reconnectAttempts(3)
                .build()
            
            client = try OddSocketsClient(config: config)
            
            // Setup event handlers
            client?.on(.connected) { data in
                print("🔗 Connected: \(data ?? "no data")")
            }
            
            client?.on(.disconnected) { data in
                print("🔌 Disconnected: \(data ?? "no data")")
            }
            
            client?.on(.error) { data in
                if let error = data as? OddSocketsError {
                    print("❌ Error: \(error.localizedDescription)")
                }
            }
            
            // Connect
            try await client?.connect()
            
            // Demonstrate bulk publishing
            await bulkPublishExample()
            
            // Demonstrate presence tracking
            await presenceExample()
            
            // Demonstrate message history
            await historyExample()
            
        } catch {
            print("❌ Advanced example failed: \(error)")
        }
    }
    
    private func bulkPublishExample() async {
        do {
            let messages = [
                bulkMessage(channel: "notifications", message: toCodable(
                    NotificationMessage(
                        title: "Welcome",
                        body: "Welcome to OddSockets!",
                        category: "system"
                    )
                )),
                bulkMessage(channel: "analytics", message: toCodable([
                    "event": "user_login",
                    "timestamp": Date().timeIntervalSince1970,
                    "user_id": client?.userId ?? "unknown"
                ])),
                bulkMessage(channel: "logs", message: toCodable(
                    SystemMessage(
                        event: "bulk_publish_test",
                        description: "Testing bulk message publishing"
                    )
                ))
            ]
            
            let results = try await client?.publishBulk(messages) ?? []
            
            print("📦 Bulk publish results:")
            for (index, result) in results.enumerated() {
                if result.success {
                    print("  ✅ Message \(index + 1): \(result.result?.messageId ?? "unknown")")
                } else {
                    print("  ❌ Message \(index + 1): \(result.error ?? "unknown error")")
                }
            }
            
        } catch {
            print("❌ Bulk publish failed: \(error)")
        }
    }
    
    private func presenceExample() async {
        do {
            let channel = try client?.channel("presence-demo")
            
            // Subscribe with presence enabled
            let options = SubscribeOptionsBuilder()
                .enablePresence(true)
                .retainHistory(false)
                .build()
            
            try await channel?.subscribe(handler: { message in
                print("📨 Presence message: \(message.data?.description ?? "nil")")
            }, options: options)
            
            // Get current presence
            let presence = try await channel?.getPresence()
            print("👥 Current presence: \(presence?.count ?? 0) users")
            print("   Users: \(presence?.users ?? [])")
            
            // Subscribe to presence updates
            channel?.presencePublisher
                .sink { presence in
                    print("👥 Presence updated: \(presence.count) users")
                }
                .store(in: &cancellables)
            
        } catch {
            print("❌ Presence example failed: \(error)")
        }
    }
    
    private func historyExample() async {
        do {
            let channel = try client?.channel("history-demo")
            
            // Subscribe with history enabled
            let subscribeOptions = SubscribeOptionsBuilder()
                .retainHistory(true)
                .build()
            
            try await channel?.subscribe(handler: { _ in }, options: subscribeOptions)
            
            // Publish some test messages
            for i in 1...5 {
                let message = ChatMessage(
                    text: "Test message \(i)",
                    username: "HistoryTester"
                )
                _ = try await channel?.publish(toCodable(message))
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
            }
            
            // Get message history
            let historyOptions = HistoryOptionsBuilder()
                .limit(10)
                .reverse(true)
                .build()
            
            let history = try await channel?.getHistory(options: historyOptions) ?? []
            
            print("📚 Message history (\(history.count) messages):")
            for (index, message) in history.enumerated() {
                print("  \(index + 1). [\(message.timestamp)] \(message.userId ?? "unknown"): \(message.data?.description ?? "nil")")
            }
            
        } catch {
            print("❌ History example failed: \(error)")
        }
    }
}

// MARK: - Error Handling Example

@MainActor
class ErrorHandlingExample {
    private var client: OddSocketsClient?
    
    func errorHandlingExample() async {
        do {
            // This will fail with invalid API key
            client = try OddSocketsClient.default(apiKey: "invalid_key")
            try await client?.connect()
            
        } catch let error as OddSocketsError {
            // Handle specific OddSockets errors
            switch error {
            case .invalidConfiguration(let message):
                print("❌ Configuration error: \(message)")
                
            case .authenticationError(let message, let code):
                print("❌ Authentication failed: \(message)")
                print("   Error code: \(code ?? "unknown")")
                
            case .connectionError(let message, let code):
                print("❌ Connection failed: \(message)")
                print("   Error code: \(code ?? "unknown")")
                
            case .channelError(let message, let channel, let code):
                print("❌ Channel error: \(message)")
                print("   Channel: \(channel ?? "unknown")")
                print("   Error code: \(code ?? "unknown")")
                
            case .networkError(let message, let underlyingError):
                print("❌ Network error: \(message)")
                if let underlyingError = underlyingError {
                    print("   Underlying: \(underlyingError.localizedDescription)")
                }
                
            case .timeout(let message):
                print("❌ Timeout: \(message)")
                
            default:
                print("❌ Other error: \(error.localizedDescription)")
            }
            
            // Access error properties
            print("   Error code: \(error.code)")
            print("   Recovery suggestion: \(error.recoverySuggestion ?? "none")")
            
        } catch {
            // Handle other errors
            print("❌ Unexpected error: \(error)")
        }
    }
}

// MARK: - Usage Examples

func runExamples() async {
    print("🚀 OddSockets Swift SDK Examples")
    print("================================")
    
    // Basic connection
    print("\n1. Basic Connection Example")
    let basicExample = BasicExample()
    await basicExample.basicConnectionExample()
    await basicExample.disconnect()
    
    // Channel subscription
    print("\n2. Channel Subscription Example")
    let channelExample = ChannelExample()
    await channelExample.channelSubscriptionExample()
    await channelExample.publishMessage()
    
    // Advanced features
    print("\n3. Advanced Features Example")
    let advancedExample = AdvancedExample()
    await advancedExample.advancedFeaturesExample()
    
    // Error handling
    print("\n4. Error Handling Example")
    let errorExample = ErrorHandlingExample()
    await errorExample.errorHandlingExample()
    
    print("\n✅ Examples completed!")
}

// MARK: - Helper Extensions for Examples

extension Message: Identifiable {
    // Message already conforms to Identifiable via its `id` property
}

extension ConnectionState {
    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting: return "Reconnecting..."
        case .failed: return "Failed"
        }
    }
}
