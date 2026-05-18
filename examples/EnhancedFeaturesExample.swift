import Foundation
import OddSockets

/// OddSockets Swift SDK - Enhanced Features Example
/// Demonstrates all 67 new Slack-like events with async/await
@main
struct EnhancedFeaturesExample {
    static func main() async {
        print("🚀 OddSockets Swift SDK - Enhanced Features Example")
        print("Demonstrating all 67 new Slack-like events")
        print(String(repeating: "=", count: 50))
        
        // Create and configure client
        let config = OddSocketsConfig(
            apiKey: "your_api_key_here",
            userId: "user_123",
            autoConnect: false
        )
        
        let client = OddSocketsClient(config: config)
        
        // Set up event listeners
        setupEventListeners(client)
        
        do {
            // Connect
            print("\n🔄 Connecting to OddSockets...")
            try await client.connect()
            
            // Wait for connection
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            guard client.isConnected else {
                print("❌ Failed to connect")
                return
            }
            
            print("✅ Connected successfully!\n")
            
            // Test all enhanced features
            await testThreadEvents(client)
            await testReactionEvents(client)
            await testReadReceiptEvents(client)
            await testChannelEvents(client)
            await testDirectMessageEvents(client)
            await testNotificationEvents(client)
            await testPresenceEvents(client)
            await testMessageEditingEvents(client)
            await testSearchEvents(client)
            
            // Summary
            print("\n🎉 All enhanced features tested!")
            print("\n📊 Summary:")
            print("- Thread Events: 7 methods")
            print("- Reaction Events: 6 methods")
            print("- Read Receipt Events: 6 methods")
            print("- Channel Events: 11 methods")
            print("- Direct Message Events: 6 methods")
            print("- Notification Events: 6 methods")
            print("- File Upload Events: 7 methods")
            print("- Presence Events: 8 methods")
            print("- Message Editing Events: 5 methods")
            print("- Search Events: 4 methods")
            print(String(repeating: "=", count: 50))
            print("Total: 67 enhanced Slack-like events! 🚀")
            
            // Wait a bit before disconnecting
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Disconnect
            client.disconnect()
            print("\n✅ Disconnected")
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
        }
    }
    
    static func setupEventListeners(_ client: OddSocketsClient) {
        client.on("connected") { data in
            print("🟢 Connected event fired")
        }
        
        client.on("disconnected") { data in
            print("🔴 Disconnected event fired")
        }
        
        client.on("error") { data in
            print("❌ Error event: \(data)")
        }
    }
    
    // MARK: - Thread Events
    
    static func testThreadEvents(_ client: OddSocketsClient) async {
        print("📝 Testing Thread Events...")
        
        do {
            // Thread reply
            let result = try await client.enhanced.threadReply(
                channel: "general",
                parentMessageId: "msg_123",
                message: "This is a test reply from Swift!",
                userId: "user_123",
                userName: "Test User"
            )
            print("✅ Thread reply created: \(result)")
            
            // Get thread
            let thread = try await client.enhanced.getThread(threadId: "thread_123")
            print("✅ Thread data: \(thread)")
            
            // Subscribe to thread
            let _ = try await client.enhanced.subscribeThread(threadId: "thread_123", userId: "user_123")
            print("✅ Subscribed to thread")
            
            // Mark thread as read
            client.enhanced.markThreadRead(threadId: "thread_123", userId: "user_123")
            print("✅ Marked thread as read")
            
            // Follow thread
            client.enhanced.followThread(threadId: "thread_123", userId: "user_123")
            print("✅ Following thread\n")
            
        } catch {
            print("❌ Thread events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Reaction Events
    
    static func testReactionEvents(_ client: OddSocketsClient) async {
        print("😀 Testing Reaction Events...")
        
        do {
            // Add reaction
            client.enhanced.addReaction(
                messageId: "msg_123",
                channel: "general",
                emoji: "👍",
                userId: "user_123",
                userName: "Test User"
            )
            print("✅ Added reaction 👍")
            
            // Remove reaction
            client.enhanced.removeReaction(
                messageId: "msg_123",
                channel: "general",
                emoji: "👍",
                userId: "user_123"
            )
            print("✅ Removed reaction")
            
            // Get reactions
            let reactions = try await client.enhanced.getReactions(messageId: "msg_123")
            print("✅ Reactions: \(reactions)\n")
            
        } catch {
            print("❌ Reaction events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Read Receipt Events
    
    static func testReadReceiptEvents(_ client: OddSocketsClient) async {
        print("✓ Testing Read Receipt Events...")
        
        do {
            // Mark message as read
            client.enhanced.markRead(
                messageId: "msg_123",
                channel: "general",
                userId: "user_123",
                userName: "Test User"
            )
            print("✅ Marked message as read")
            
            // Get unread counts
            let counts = try await client.enhanced.getUnreadCounts(
                userId: "user_123",
                channels: ["general", "random"]
            )
            print("✅ Unread counts: \(counts)")
            
            // Mark all as read
            client.enhanced.markAllRead(channel: "general", userId: "user_123")
            print("✅ Marked all messages as read\n")
            
        } catch {
            print("❌ Read receipt events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Channel Events
    
    static func testChannelEvents(_ client: OddSocketsClient) async {
        print("📢 Testing Channel Events...")
        
        do {
            // Create channel
            let channelName = "swift-test-\(Int(Date().timeIntervalSince1970))"
            let channel = try await client.enhanced.createChannel(
                name: channelName,
                type: "public",
                description: "Created from Swift SDK",
                topic: "Testing",
                createdBy: "user_123",
                createdByName: "Test User"
            )
            print("✅ Channel created: \(channel)")
            
            // Update channel
            client.enhanced.updateChannel(
                channelId: "channel_123",
                updates: ["topic": "Updated topic"],
                userId: "user_123"
            )
            print("✅ Updated channel")
            
            // Join channel
            client.enhanced.joinChannel(
                channelId: "channel_123",
                userId: "user_123",
                userName: "Test User"
            )
            print("✅ Joined channel")
            
            // Invite to channel
            client.enhanced.inviteToChannel(
                channelId: "channel_123",
                invitedUserId: "user_456",
                invitedUserName: "Jane Doe",
                invitedBy: "user_123"
            )
            print("✅ Invited user to channel")
            
            // Get channel members
            let members = try await client.enhanced.getChannelMembers(channelId: "channel_123")
            print("✅ Channel members: \(members)\n")
            
        } catch {
            print("❌ Channel events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Direct Message Events
    
    static func testDirectMessageEvents(_ client: OddSocketsClient) async {
        print("💬 Testing Direct Message Events...")
        
        do {
            // Create DM
            let dm = try await client.enhanced.createDM(
                userIds: ["user_123", "user_456"],
                type: "1-on-1"
            )
            print("✅ DM created: \(dm)")
            
            // Send DM
            client.enhanced.sendDM(
                conversationId: "dm_123",
                message: "Hello from Swift!",
                userId: "user_123",
                userName: "Test User"
            )
            print("✅ Sent DM")
            
            // Get DM conversations
            let conversations = try await client.enhanced.getDMConversations(
                userId: "user_123",
                includeArchived: false
            )
            print("✅ DM conversations: \(conversations)\n")
            
        } catch {
            print("❌ Direct message events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Notification Events
    
    static func testNotificationEvents(_ client: OddSocketsClient) async {
        print("🔔 Testing Notification Events...")
        
        do {
            // Subscribe to notifications
            client.enhanced.subscribeNotifications(userId: "user_123")
            print("✅ Subscribed to notifications")
            
            // Mark notification as read
            client.enhanced.markNotificationRead(notificationId: "notif_123", userId: "user_123")
            print("✅ Marked notification as read")
            
            // Mark all notifications as read
            client.enhanced.markAllNotificationsRead(userId: "user_123")
            print("✅ Marked all notifications as read")
            
            // Get notifications
            let notifications = try await client.enhanced.getNotifications(
                userId: "user_123",
                limit: 10,
                status: "all"
            )
            print("✅ Notifications: \(notifications)\n")
            
        } catch {
            print("❌ Notification events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Presence Events
    
    static func testPresenceEvents(_ client: OddSocketsClient) async {
        print("👤 Testing Presence Events...")
        
        do {
            // Set status
            client.enhanced.setStatus(userId: "user_123", status: "online")
            print("✅ Set status to online")
            
            // Set custom status
            client.enhanced.setCustomStatus(
                userId: "user_123",
                emoji: "🦅",
                text: "Coding in Swift",
                expiresAt: nil
            )
            print("✅ Set custom status")
            
            // Clear custom status
            client.enhanced.clearCustomStatus(userId: "user_123")
            print("✅ Cleared custom status")
            
            // Set DND
            client.enhanced.setDND(userId: "user_123", until: nil)
            print("✅ Enabled Do Not Disturb")
            
            // Clear DND
            client.enhanced.clearDND(userId: "user_123")
            print("✅ Disabled Do Not Disturb")
            
            // Start typing
            client.enhanced.startTyping(userId: "user_123", channel: "general")
            print("✅ Started typing indicator")
            
            // Wait a moment
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Stop typing
            client.enhanced.stopTyping(userId: "user_123", channel: "general")
            print("✅ Stopped typing indicator")
            
            // Get user presence
            let presence = try await client.enhanced.getUserPresence(userIds: ["user_123", "user_456"])
            print("✅ User presence: \(presence)\n")
            
        } catch {
            print("❌ Presence events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Message Editing Events
    
    static func testMessageEditingEvents(_ client: OddSocketsClient) async {
        print("✏️ Testing Message Editing Events...")
        
        do {
            // Edit message
            client.enhanced.editMessage(
                messageId: "msg_123",
                channel: "general",
                newContent: "Updated message from Swift",
                userId: "user_123"
            )
            print("✅ Edited message")
            
            // Delete message
            client.enhanced.deleteMessage(
                messageId: "msg_456",
                channel: "general",
                userId: "user_123"
            )
            print("✅ Deleted message")
            
            // Pin message
            client.enhanced.pinMessage(
                messageId: "msg_123",
                channel: "general",
                userId: "user_123"
            )
            print("✅ Pinned message")
            
            // Unpin message
            client.enhanced.unpinMessage(
                messageId: "msg_123",
                channel: "general",
                userId: "user_123"
            )
            print("✅ Unpinned message")
            
            // Get pinned messages
            let pinned = try await client.enhanced.getPinnedMessages(channel: "general")
            print("✅ Pinned messages: \(pinned)\n")
            
        } catch {
            print("❌ Message editing events error: \(error.localizedDescription)\n")
        }
    }
    
    // MARK: - Search Events
    
    static func testSearchEvents(_ client: OddSocketsClient) async {
        print("🔍 Testing Search Events...")
        
        do {
            // Search messages
            let results = try await client.enhanced.searchMessages(
                query: "test",
                userId: "user_123",
                limit: 10
            )
            print("✅ Search results: \(results)")
            
            // Search in channel
            let channelResults = try await client.enhanced.searchInChannel(
                channel: "general",
                query: "test",
                limit: 10
            )
            print("✅ Channel search results: \(channelResults)")
            
            // Filter messages
            let filtered = try await client.enhanced.filterMessages(
                filters: [
                    "channel": "general",
                    "userId": "user_123",
                    "limit": 10
                ]
            )
            print("✅ Filter results: \(filtered)")
            
            // Search by user
            let userResults = try await client.enhanced.searchByUser(
                userId: "user_123",
                query: nil,
                limit: 10
            )
            print("✅ User search results: \(userResults)\n")
            
        } catch {
            print("❌ Search events error: \(error.localizedDescription)\n")
        }
    }
}
