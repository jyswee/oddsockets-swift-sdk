# OddSockets Swift SDK

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

The official Swift SDK for OddSockets real-time messaging platform. Built with modern Swift patterns including async/await, Combine, and SwiftUI integration.

## Features

- ✅ **Modern Swift**: Built with async/await, Combine, and SwiftUI support
- ✅ **Multi-platform**: iOS, macOS, tvOS, and watchOS support
- ✅ **Type Safety**: Full Swift type safety with comprehensive error handling
- ✅ **Reactive**: Combine publishers for reactive programming
- ✅ **ObservableObject**: SwiftUI-ready with @Published properties
- ✅ **Bulk Publishing**: Efficient multi-message publishing
- ✅ **Message History**: Retrieve and filter historical messages
- ✅ **Presence Tracking**: Real-time user presence information
- ✅ **Auto-reconnection**: Automatic reconnection with exponential backoff
- ✅ **Thread Safe**: All operations are thread-safe and MainActor-compliant

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/jyswee/oddsockets-swift-sdk.git", from: "0.1.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/jyswee/oddsockets-swift-sdk.git`
3. Select version and add to your target

### Requirements

- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Swift 5.9+
- Xcode 15.0+

## Quick Start

### Basic Usage

```swift
import OddSockets

@MainActor
class MessagingService: ObservableObject {
    @Published var isConnected = false
    @Published var messages: [Message] = []
    
    private var client: OddSocketsClient?
    private var channel: OddSocketsChannel?
    
    func connect() async {
        do {
            // Create client
            let config = try OddSocketsConfigBuilder()
                .apiKey("ak_your_api_key_here")
                .userId("user123")
                .build()
            
            client = try OddSocketsClient(config: config)
            
            // Connect
            try await client?.connect()
            isConnected = true
            
            // Subscribe to channel
            channel = try client?.channel("chat")
            try await channel?.subscribe { [weak self] message in
                await MainActor.run {
                    self?.messages.append(message)
                }
            }
            
        } catch {
            print("Connection failed: \(error)")
        }
    }
    
    func sendMessage(_ text: String) async {
        do {
            let chatMessage = ChatMessage(text: text, username: "User")
            _ = try await channel?.publish(toCodable(chatMessage))
        } catch {
            print("Send failed: \(error)")
        }
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import OddSockets

struct ChatView: View {
    @StateObject private var messaging = MessagingService()
    @State private var messageText = ""
    
    var body: some View {
        VStack {
            // Connection status
            HStack {
                Circle()
                    .fill(messaging.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)
                Text(messaging.isConnected ? "Connected" : "Disconnected")
                Spacer()
            }
            .padding()
            
            // Messages
            List(messaging.messages) { message in
                VStack(alignment: .leading) {
                    Text(message.userId ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(message.data?.stringValue ?? "")
                        .font(.body)
                }
            }
            
            // Input
            HStack {
                TextField("Message", text: $messageText)
                Button("Send") {
                    Task {
                        await messaging.sendMessage(messageText)
                        messageText = ""
                    }
                }
                .disabled(messageText.isEmpty || !messaging.isConnected)
            }
            .padding()
        }
        .task {
            await messaging.connect()
        }
    }
}
```

## Configuration

### Basic Configuration

```swift
// Simple configuration
let client = try OddSocketsClient.default(apiKey: "ak_your_api_key_here")

// Custom configuration
let config = try OddSocketsConfigBuilder()
    .apiKey("ak_your_api_key_here")
    .userId("user123")
    .managerUrl("https://manager1.oddsockets.tyga.network")
    .timeout(15)
    .heartbeatInterval(30)
    .reconnectAttempts(5)
    .build()

let client = try OddSocketsClient(config: config)
```

### Environment-Specific Configuration

```swift
// Development
let devConfig = try OddSocketsConfigBuilder()
    .apiKey("ak_dev_key")
    .development() // Sets localhost URL and debug settings
    .build()

// Production
let prodConfig = try OddSocketsConfigBuilder()
    .apiKey("ak_prod_key")
    .production() // Sets production URL and optimized settings
    .build()
```

## Core Concepts

### Connection Management

```swift
// Connect
try await client.connect()

// Check connection state
if client.isConnected {
    print("Connected!")
}

// Listen for connection events
client.on(.connected) { data in
    print("Connected: \(data)")
}

client.on(.disconnected) { data in
    print("Disconnected: \(data)")
}

// Disconnect
await client.disconnect()
```

### Channel Operations

```swift
// Get channel
let channel = try client.channel("my-channel")

// Subscribe with options
let options = SubscribeOptionsBuilder()
    .enablePresence(true)
    .retainHistory(true)
    .build()

try await channel.subscribe(handler: { message in
    print("Received: \(message.data)")
}, options: options)

// Publish message
let result = try await channel.publish("Hello, World!")
print("Published: \(result.messageId)")

// Unsubscribe
await channel.unsubscribe()
```

### Message Types

```swift
// Simple text message
try await channel.publish(text: "Hello!")

// Structured message
let chatMessage = ChatMessage(
    text: "Hello from Swift!",
    username: "SwiftUser"
)
try await channel.publish(toCodable(chatMessage))

// Dictionary message
try await channel.publish(dictionary: [
    "type": "notification",
    "title": "New Message",
    "body": "You have a new message"
])
```

## Advanced Features

### Bulk Publishing

```swift
let messages = [
    bulkMessage(channel: "notifications", message: toCodable("Message 1")),
    bulkMessage(channel: "alerts", message: toCodable("Alert!")),
    bulkMessage(channel: "logs", message: toCodable(["event": "user_action"]))
]

let results = try await client.publishBulk(messages)
for result in results {
    if result.success {
        print("✅ Published: \(result.result?.messageId)")
    } else {
        print("❌ Failed: \(result.error)")
    }
}
```

### Message History

```swift
// Get recent messages
let options = HistoryOptionsBuilder()
    .limit(50)
    .reverse(true)
    .build()

let history = try await channel.getHistory(options: options)
print("Retrieved \(history.count) messages")

// Filter by time range
let filtered = HistoryOptionsBuilder()
    .start(Date().addingTimeInterval(-3600)) // Last hour
    .limit(100)
    .build()

let recentMessages = try await channel.getHistory(options: filtered)
```

### Presence Tracking

```swift
// Enable presence on subscription
let options = SubscribeOptionsBuilder()
    .enablePresence(true)
    .build()

try await channel.subscribe(handler: { _ in }, options: options)

// Get current presence
let presence = try await channel.getPresence()
print("Users online: \(presence.count)")
print("User list: \(presence.users)")

// Listen for presence changes
channel.presencePublisher
    .sink { presence in
        print("Presence updated: \(presence.count) users")
    }
    .store(in: &cancellables)
```

### Combine Integration

```swift
import Combine

class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var connectionState: ConnectionState = .disconnected
    
    private var client: OddSocketsClient?
    private var cancellables = Set<AnyCancellable>()
    
    func setup() async {
        client = try? OddSocketsClient.default(apiKey: "ak_key")
        
        // Bind connection state
        client?.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionState, on: self)
            .store(in: &cancellables)
        
        // Subscribe to messages
        client?.messagePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.messages.append(message)
            }
            .store(in: &cancellables)
        
        try? await client?.connect()
    }
}
```

### Error Handling

```swift
do {
    try await client.connect()
} catch let error as OddSocketsError {
    switch error {
    case .invalidConfiguration(let message):
        print("Config error: \(message)")
        
    case .authenticationError(let message, let code):
        print("Auth failed: \(message) (\(code ?? "unknown"))")
        
    case .connectionError(let message, let code):
        print("Connection failed: \(message)")
        
    case .networkError(let message, let underlyingError):
        print("Network error: \(message)")
        if let underlying = underlyingError {
            print("Underlying: \(underlying)")
        }
        
    default:
        print("Other error: \(error.localizedDescription)")
    }
    
    // Access error properties
    print("Error code: \(error.code)")
    print("Recovery: \(error.recoverySuggestion ?? "none")")
}
```

## API Reference

### OddSocketsClient

The main client class for connecting to OddSockets.

#### Properties

```swift
@Published var connectionState: ConnectionState
@Published var isConnected: Bool
@Published var workerInfo: (workerId: String?, workerUrl: String?)

var userId: String
var eventPublisher: AnyPublisher<(EventType, Any?), Never>
var messagePublisher: AnyPublisher<Message, Never>
var errorPublisher: AnyPublisher<OddSocketsError, Never>
```

#### Methods

```swift
init(config: OddSocketsConfig) throws
func connect() async throws
func disconnect() async
func channel(_ name: String) throws -> OddSocketsChannel
func publishBulk(_ messages: [BulkMessage]) async throws -> [BulkResult]
func on(_ eventType: EventType, handler: @escaping AsyncEventHandler)
func off(_ eventType: EventType)
```

### OddSocketsChannel

Channel class for managing real-time messaging.

#### Properties

```swift
@Published var isSubscribed: Bool
@Published var subscriptionOptions: SubscribeOptions?
@Published var messageHistory: [Message]
@Published var presenceInfo: PresenceInfo?

var channelName: String
var messagePublisher: AnyPublisher<Message, Never>
var presencePublisher: AnyPublisher<PresenceInfo, Never>
var eventPublisher: AnyPublisher<(EventType, Any?), Never>
```

#### Methods

```swift
func subscribe(handler: @escaping AsyncMessageHandler, options: SubscribeOptions) async throws
func unsubscribe() async
func publish(_ message: AnyCodable?, options: PublishOptions?) async throws -> PublishResult
func getHistory(options: HistoryOptions?) async throws -> [Message]
func getPresence() async throws -> PresenceInfo
func on(_ eventType: EventType, handler: @escaping AsyncEventHandler)
func off(_ eventType: EventType)
```

### Configuration Classes

#### OddSocketsConfig

```swift
struct OddSocketsConfig {
    let apiKey: String
    let managerUrl: String
    let userId: String?
    let autoConnect: Bool
    let reconnectAttempts: Int
    let heartbeatInterval: TimeInterval
    let timeout: TimeInterval
}
```

#### OddSocketsConfigBuilder

```swift
class OddSocketsConfigBuilder {
    func apiKey(_ apiKey: String) -> OddSocketsConfigBuilder
    func managerUrl(_ url: String) -> OddSocketsConfigBuilder
    func userId(_ userId: String) -> OddSocketsConfigBuilder
    func autoConnect(_ autoConnect: Bool) -> OddSocketsConfigBuilder
    func reconnectAttempts(_ attempts: Int) -> OddSocketsConfigBuilder
    func heartbeatInterval(_ interval: TimeInterval) -> OddSocketsConfigBuilder
    func timeout(_ timeout: TimeInterval) -> OddSocketsConfigBuilder
    func build() throws -> OddSocketsConfig
}
```

### Data Models

#### Message

```swift
struct Message: Codable, Identifiable, Equatable {
    let id: String
    let channel: String
    let data: AnyCodable?
    let timestamp: Date
    let userId: String?
    let metadata: [String: AnyCodable]?
}
```

#### PresenceInfo

```swift
struct PresenceInfo: Codable, Equatable {
    let channel: String
    let users: [String]
    let count: Int
    let timestamp: Date
}
```

#### PublishResult

```swift
struct PublishResult: Codable, Equatable {
    let messageId: String
    let timestamp: Date
    let channel: String
    let success: Bool
}
```

### Options Classes

#### SubscribeOptions

```swift
struct SubscribeOptions: Codable, Equatable {
    let enablePresence: Bool
    let retainHistory: Bool
    let filterExpression: String?
}
```

#### PublishOptions

```swift
struct PublishOptions: Codable, Equatable {
    let ttl: Int?
    let metadata: [String: AnyCodable]?
    let storeInHistory: Bool
}
```

#### HistoryOptions

```swift
struct HistoryOptions: Codable, Equatable {
    let limit: Int?
    let start: Date?
    let end: Date?
    let reverse: Bool
}
```

### Enums

#### ConnectionState

```swift
enum ConnectionState: String, CaseIterable, Codable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}
```

#### EventType

```swift
enum EventType: String, CaseIterable, Codable {
    case connected
    case disconnected
    case reconnected
    case error
    case message
    case presence
    case workerAssigned
    case maxReconnectAttemptsReached
}
```

### Error Types

#### OddSocketsError

```swift
enum OddSocketsError: Error, LocalizedError {
    case invalidConfiguration(String)
    case connectionError(String, code: String?)
    case authenticationError(String, code: String?)
    case channelError(String, channel: String?, code: String?)
    case messageError(String, messageId: String?, code: String?)
    case networkError(String, underlyingError: Error?)
    case timeout(String)
    case generic(String, code: String?, details: [String: Any]?)
}
```

## Best Practices

### Memory Management

```swift
// Use weak references in closures
client.on(.message) { [weak self] data in
    self?.handleMessage(data)
}

// Store cancellables properly
private var cancellables = Set<AnyCancellable>()

client.messagePublisher
    .sink { message in
        // Handle message
    }
    .store(in: &cancellables)
```

### Error Handling

```swift
// Always handle errors appropriately
do {
    try await client.connect()
} catch {
    // Log error and show user-friendly message
    logger.error("Connection failed: \(error)")
    showErrorAlert("Unable to connect. Please try again.")
}
```

### Threading

```swift
// Use @MainActor for UI updates
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    
    func addMessage(_ message: Message) {
        messages.append(message)
    }
}

// Ensure UI updates happen on main thread
client.messagePublisher
    .receive(on: DispatchQueue.main)
    .sink { message in
        viewModel.addMessage(message)
    }
    .store(in: &cancellables)
```

### Resource Cleanup

```swift
class MessagingService {
    private var client: OddSocketsClient?
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        Task {
            await client?.disconnect()
        }
        cancellables.removeAll()
    }
}
```

## Performance Considerations

- **Connection Pooling**: The SDK automatically manages connections efficiently
- **Message Batching**: Use bulk publishing for multiple messages
- **Memory Usage**: Message history is automatically limited to prevent memory issues
- **Background Processing**: All network operations are performed off the main thread
- **Reconnection**: Automatic reconnection with exponential backoff prevents excessive retries

## Troubleshooting

### Common Issues

1. **Connection Fails**
   - Verify your API key is correct and active
   - Check network connectivity
   - Ensure the manager URL is accessible

2. **Messages Not Received**
   - Verify channel subscription is active
   - Check if filters are blocking messages
   - Ensure the client is connected

3. **Memory Issues**
   - Limit message history retention
   - Use weak references in closures
   - Clean up cancellables properly

### Debug Mode

```swift
// Enable debug logging
import Logging
setGlobalLogLevel(.debug)

// Print SDK information
#if DEBUG
printSDKInfo()
#endif
```

## Examples

See the [Examples](Examples/) directory for complete working examples:

- **BasicUsage.swift**: Basic connection and messaging
- **SwiftUIChat.swift**: Complete SwiftUI chat application
- **CombineIntegration.swift**: Reactive programming with Combine
- **AdvancedFeatures.swift**: Bulk publishing, presence, and history

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## Get a Free API Key

```bash
curl -X POST https://oddsockets.com/api/agent-signup \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com", "agentName": "my-agent", "platform": "swift"}'
curl -X POST https://oddsockets.com/api/agent-signup/verify \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com", "code": "123456", "agentName": "my-agent"}'
```

## Plans

| | Free | Starter | Pro |
|---|---|---|---|
| **Price** | $0/mo | $49.99/mo | $299/mo |
| **MAU** | 100 | 1,000 | 50,000 |
| **Concurrent connections** | 50 | 1,000 | Unlimited |
| **Messages/day** | 10,000 | 4,320,000 | Unlimited |
| **Channels** | 10 | Unlimited | Unlimited |
| **Storage** | 100MB (24h) | 50GB (6 months) | Unlimited |

## Support

- [Documentation](https://docs.oddsockets.com/sdks/swift)
- [Issue Tracker](https://github.com/jyswee/oddsockets-swift-sdk/issues)
- [Email Support](mailto:support@oddsockets.com)

## License

MIT License - Copyright (c) 2026 Joe Wee, Tyga.Cloud Ltd. See [LICENSE](LICENSE) for details.
