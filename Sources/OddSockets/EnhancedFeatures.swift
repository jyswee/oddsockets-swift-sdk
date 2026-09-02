import Foundation
import Combine

/// Enhanced Features for OddSockets Swift SDK
/// Provides 67 new Slack-like events with async/await support
@MainActor
public class EnhancedFeatures {
    private weak var client: OddSocketsClient?
    private let timeout: TimeInterval = 10.0
    
    init(client: OddSocketsClient) {
        self.client = client
    }
    
    // MARK: - Thread Events
    
    /// Reply to a message in a thread
    public func threadReply(
        channel: String,
        parentMessageId: String,
        message: String,
        userId: String,
        userName: String
    ) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        let params: [String: Any] = [
            "channel": channel,
            "parentMessageId": parentMessageId,
            "message": message,
            "userId": userId,
            "userName": userName
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("thread_reply_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "thread_reply" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("thread_reply_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("thread_reply_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("thread_reply", data: params)
        }
    }
    
    /// Get thread with all replies
    public func getThread(threadId: String) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("thread_data", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_thread" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("thread_data", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("thread_data", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_thread", data: ["threadId": threadId])
        }
    }
    
    /// Subscribe to thread updates
    public func subscribeThread(threadId: String, userId: String) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("thread_subscribed", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "subscribe_thread" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("thread_subscribed", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("thread_subscribed", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("subscribe_thread", data: ["threadId": threadId, "userId": userId])
        }
    }
    
    /// Mark thread as read
    public func markThreadRead(threadId: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("mark_thread_read", data: ["threadId": threadId, "userId": userId])
    }
    
    /// Follow a thread
    public func followThread(threadId: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("follow_thread", data: ["threadId": threadId, "userId": userId])
    }
    
    /// Unfollow a thread
    public func unfollowThread(threadId: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("unfollow_thread", data: ["threadId": threadId, "userId": userId])
    }
    
    // MARK: - Reaction Events
    
    /// Add reaction to a message
    public func addReaction(
        messageId: String,
        channel: String,
        emoji: String,
        userId: String,
        userName: String
    ) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "messageId": messageId,
            "channel": channel,
            "emoji": emoji,
            "userId": userId,
            "userName": userName
        ]
        
        client.emit("add_reaction", data: params)
    }
    
    /// Remove reaction from a message
    public func removeReaction(
        messageId: String,
        channel: String,
        emoji: String,
        userId: String
    ) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "messageId": messageId,
            "channel": channel,
            "emoji": emoji,
            "userId": userId
        ]
        
        client.emit("remove_reaction", data: params)
    }
    
    /// Get all reactions for a message
    public func getReactions(messageId: String) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("message_reactions", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_reactions" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("message_reactions", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("message_reactions", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_reactions", data: ["messageId": messageId])
        }
    }
    
    // MARK: - Read Receipt Events
    
    /// Mark message as read
    public func markRead(
        messageId: String,
        channel: String,
        userId: String,
        userName: String
    ) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "messageId": messageId,
            "channel": channel,
            "userId": userId,
            "userName": userName
        ]
        
        client.emit("mark_read", data: params)
    }
    
    /// Get unread counts for channels
    public func getUnreadCounts(userId: String, channels: [String]) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("unread_counts", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_unread_counts" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("unread_counts", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("unread_counts", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_unread_counts", data: ["userId": userId, "channels": channels])
        }
    }
    
    /// Mark all messages in channel as read
    public func markAllRead(channel: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("mark_all_read", data: ["channel": channel, "userId": userId])
    }
    
    // MARK: - Channel Events
    
    /// Create a new channel
    public func createChannel(
        name: String,
        type: String,
        description: String,
        topic: String,
        createdBy: String,
        createdByName: String
    ) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        let params: [String: Any] = [
            "name": name,
            "type": type,
            "description": description,
            "topic": topic,
            "createdBy": createdBy,
            "createdByName": createdByName,
            "members": []
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("channel_create_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "create_channel" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("channel_create_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("channel_create_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("create_channel", data: params)
        }
    }
    
    /// Update channel details
    public func updateChannel(channelId: String, updates: [String: Any], userId: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "channelId": channelId,
            "updates": updates,
            "userId": userId
        ]
        
        client.emit("update_channel", data: params)
    }
    
    /// Archive a channel
    public func archiveChannel(channelId: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("archive_channel", data: ["channelId": channelId, "userId": userId])
    }
    
    /// Invite user to channel
    public func inviteToChannel(
        channelId: String,
        invitedUserId: String,
        invitedUserName: String,
        invitedBy: String
    ) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "channelId": channelId,
            "invitedUserId": invitedUserId,
            "invitedUserName": invitedUserName,
            "invitedBy": invitedBy
        ]
        
        client.emit("invite_to_channel", data: params)
    }
    
    /// Remove user from channel
    public func removeFromChannel(channelId: String, removedUserId: String, removedBy: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "channelId": channelId,
            "removedUserId": removedUserId,
            "removedBy": removedBy
        ]
        
        client.emit("remove_from_channel", data: params)
    }
    
    /// Join a public channel
    public func joinChannel(channelId: String, userId: String, userName: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "channelId": channelId,
            "userId": userId,
            "userName": userName
        ]
        
        client.emit("join_channel", data: params)
    }
    
    /// Leave a channel
    public func leaveChannel(channelId: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("leave_channel", data: ["channelId": channelId, "userId": userId])
    }
    
    /// Get channel members
    public func getChannelMembers(channelId: String) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("channel_members", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_channel_members" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("channel_members", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("channel_members", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_channel_members", data: ["channelId": channelId])
        }
    }
    
    // MARK: - Direct Message Events
    
    /// Create or get DM conversation
    public func createDM(userIds: [String], type: String) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        let params: [String: Any] = [
            "userIds": userIds,
            "type": type
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("dm_create_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "create_dm" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("dm_create_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("dm_create_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("create_dm", data: params)
        }
    }
    
    /// Send direct message
    public func sendDM(conversationId: String, message: String, userId: String, userName: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "conversationId": conversationId,
            "message": message,
            "userId": userId,
            "userName": userName
        ]
        
        client.emit("send_dm", data: params)
    }
    
    /// Get user's DM conversations
    public func getDMConversations(userId: String, includeArchived: Bool) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("dm_conversations", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_dm_conversations" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("dm_conversations", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("dm_conversations", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_dm_conversations", data: ["userId": userId, "includeArchived": includeArchived])
        }
    }
    
    // MARK: - Notification Events
    
    /// Subscribe to user notifications
    public func subscribeNotifications(userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("subscribe_notifications", data: ["userId": userId])
    }
    
    /// Mark notification as read
    public func markNotificationRead(notificationId: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "notificationId": notificationId,
            "userId": userId
        ]
        
        client.emit("mark_notification_read", data: params)
    }
    
    /// Mark all notifications as read
    public func markAllNotificationsRead(userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("mark_all_notifications_read", data: ["userId": userId])
    }
    
    /// Clear all notifications
    public func clearNotifications(userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("clear_notifications", data: ["userId": userId])
    }
    
    /// Get user notifications
    public func getNotifications(userId: String, limit: Int, status: String?) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        var params: [String: Any] = [
            "userId": userId,
            "limit": limit
        ]
        
        if let status = status {
            params["status"] = status
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("notifications_data", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_notifications" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("notifications_data", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("notifications_data", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_notifications", data: params)
        }
    }
    
    // MARK: - Presence Events
    
    /// Set user status
    public func setStatus(userId: String, status: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("set_status", data: ["userId": userId, "status": status])
    }
    
    /// Set custom status
    public func setCustomStatus(userId: String, emoji: String, text: String, expiresAt: String?) {
        guard let client = client, client.isConnected else { return }
        
        var params: [String: Any] = [
            "userId": userId,
            "emoji": emoji,
            "text": text
        ]
        
        if let expiresAt = expiresAt {
            params["expiresAt"] = expiresAt
        }
        
        client.emit("set_custom_status", data: params)
    }
    
    /// Clear custom status
    public func clearCustomStatus(userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("clear_custom_status", data: ["userId": userId])
    }
    
    /// Enable Do Not Disturb
    public func setDND(userId: String, until: String?) {
        guard let client = client, client.isConnected else { return }
        
        var params: [String: Any] = ["userId": userId]
        if let until = until {
            params["until"] = until
        }
        
        client.emit("set_dnd", data: params)
    }
    
    /// Disable Do Not Disturb
    public func clearDND(userId: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("clear_dnd", data: ["userId": userId])
    }
    
    /// Start typing indicator
    public func startTyping(userId: String, channel: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("start_typing", data: ["userId": userId, "channel": channel])
    }
    
    /// Stop typing indicator
    public func stopTyping(userId: String, channel: String) {
        guard let client = client, client.isConnected else { return }
        client.emit("stop_typing", data: ["userId": userId, "channel": channel])
    }
    
    /// Get user presence information
    public func getUserPresence(userIds: [String]) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("user_presence_data", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_user_presence" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("user_presence_data", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("user_presence_data", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_user_presence", data: ["userIds": userIds])
        }
    }
    
    // MARK: - Message Editing Events
    
    /// Edit a message
    public func editMessage(messageId: String, channel: String, newContent: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "messageId": messageId,
            "channel": channel,
            "newContent": newContent,
            "userId": userId
        ]
        
        client.emit("edit_message", data: params)
    }
    
    /// Delete a message
    public func deleteMessage(messageId: String, channel: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "messageId": messageId,
            "channel": channel,
            "userId": userId
        ]
        
        client.emit("delete_message", data: params)
    }
    
    /// Pin message to channel
    public func pinMessage(messageId: String, channel: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "messageId": messageId,
            "channel": channel,
            "userId": userId
        ]
        
        client.emit("pin_message", data: params)
    }
    
    /// Unpin message from channel
    public func unpinMessage(messageId: String, channel: String, userId: String) {
        guard let client = client, client.isConnected else { return }
        
        let params: [String: Any] = [
            "messageId": messageId,
            "channel": channel,
            "userId": userId
        ]
        
        client.emit("unpin_message", data: params)
    }
    
    /// Get pinned messages in channel
    public func getPinnedMessages(channel: String) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("pinned_messages", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "get_pinned_messages" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("pinned_messages", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("pinned_messages", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("get_pinned_messages", data: ["channel": channel])
        }
    }
    
    // MARK: - Search Events
    
    /// Search messages across all channels
    public func searchMessages(query: String, userId: String, limit: Int) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        let params: [String: Any] = [
            "query": query,
            "userId": userId,
            "limit": limit
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("search_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "search_messages" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("search_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("search_results", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("search_messages", data: params)
        }
    }
    
    /// Filter messages by criteria
    public func filterMessages(filters: [String: Any]) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("filter_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "filter_messages" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("filter_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("filter_results", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("filter_messages", data: filters)
        }
    }
    
    /// Search within specific channel
    public func searchInChannel(channel: String, query: String, limit: Int) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        let params: [String: Any] = [
            "channel": channel,
            "query": query,
            "limit": limit
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("channel_search_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "search_in_channel" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("channel_search_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("channel_search_results", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("search_in_channel", data: params)
        }
    }
    
    /// Search messages by user
    public func searchByUser(userId: String, query: String?, limit: Int) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }
        
        var params: [String: Any] = [
            "userId": userId,
            "limit": limit
        ]
        
        if let query = query {
            params["query"] = query
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?
            
            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("user_search_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "search_by_user" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("user_search_results", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }
            
            client.once("user_search_results", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("search_by_user", data: params)
        }
    }

    // MARK: - Challenge / Leaderboard / Achievement Events

    /// Create a challenge (competition/leaderboard).
    ///
    /// - Parameters:
    ///   - challengeId: Stable identifier for the challenge.
    ///   - metric: The scored metric (e.g. "score", "time").
    ///   - ranked: Whether the challenge maintains a leaderboard. Defaults to worker behaviour when omitted.
    ///   - channel: Optional channel to scope broadcasts to.
    ///   - resultWebhookUrl: Optional webhook invoked when the challenge resolves.
    ///   - standingsUrl: Optional URL for published standings.
    public func createChallenge(
        challengeId: String,
        metric: String,
        ranked: Bool? = nil,
        channel: String? = nil,
        resultWebhookUrl: String? = nil,
        standingsUrl: String? = nil
    ) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        var params: [String: Any] = [
            "challengeId": challengeId,
            "metric": metric
        ]
        if let ranked = ranked {
            params["ranked"] = ranked
        }
        if let channel = channel {
            params["channel"] = channel
        }
        if let resultWebhookUrl = resultWebhookUrl {
            params["resultWebhookUrl"] = resultWebhookUrl
        }
        if let standingsUrl = standingsUrl {
            params["standingsUrl"] = standingsUrl
        }

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("challenge_create_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "challenge_create" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("challenge_create_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("challenge_create_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("challenge_create", data: params)
        }
    }

    /// Report progress toward a challenge (fire-and-forget).
    ///
    /// The worker echoes `challenge_progress` (and `leaderboard_rank_change` when
    /// the player's rank moves) to other members of the room.
    public func reportProgress(
        challengeId: String,
        value: Double,
        metric: String? = nil,
        eventId: String? = nil,
        cohort: String? = nil,
        platform: String? = nil,
        channel: String? = nil
    ) {
        guard let client = client, client.isConnected else { return }

        var params: [String: Any] = [
            "challengeId": challengeId,
            "value": value
        ]
        if let metric = metric {
            params["metric"] = metric
        }
        if let eventId = eventId {
            params["eventId"] = eventId
        }
        if let cohort = cohort {
            params["cohort"] = cohort
        }
        if let platform = platform {
            params["platform"] = platform
        }
        if let channel = channel {
            params["channel"] = channel
        }

        client.emit("challenge_progress", data: params)
    }

    /// Complete (resolve) a challenge for the current player.
    ///
    /// - Parameters:
    ///   - challengeId: The challenge being resolved.
    ///   - outcome: One of `completed`, `failed`, `expired`, `conceded`, `tied`.
    ///   - eventId: Optional idempotency key.
    ///   - reward: Optional reward payload granted on completion.
    public func completeChallenge(
        challengeId: String,
        outcome: String,
        eventId: String? = nil,
        reward: [String: Any]? = nil
    ) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        var params: [String: Any] = [
            "challengeId": challengeId,
            "outcome": outcome
        ]
        if let eventId = eventId {
            params["eventId"] = eventId
        }
        if let reward = reward {
            params["reward"] = reward
        }

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("challenge_complete_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "challenge_complete" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("challenge_complete_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("challenge_complete_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("challenge_complete", data: params)
        }
    }

    /// Unlock (or progress) an achievement (fire-and-forget).
    ///
    /// When `percentComplete` is below 100 the worker broadcasts
    /// `achievement_progress`; at 100 (or when omitted) it broadcasts
    /// `achievement_unlock`.
    public func unlockAchievement(
        achievementId: String,
        name: String? = nil,
        tier: String? = nil,
        percentComplete: Double? = nil,
        challengeId: String? = nil,
        channel: String? = nil
    ) {
        guard let client = client, client.isConnected else { return }

        var params: [String: Any] = [
            "achievementId": achievementId
        ]
        if let name = name {
            params["name"] = name
        }
        if let tier = tier {
            params["tier"] = tier
        }
        if let percentComplete = percentComplete {
            params["percentComplete"] = percentComplete
        }
        if let challengeId = challengeId {
            params["challengeId"] = challengeId
        }
        if let channel = channel {
            params["channel"] = channel
        }

        client.emit("achievement_unlock", data: params)
    }

    /// Get leaderboard standings for a challenge.
    ///
    /// - Parameters:
    ///   - challengeId: The challenge to read standings for.
    ///   - limit: Maximum rows to return. Defaults to 20.
    ///   - offset: Row offset for pagination. Defaults to 0.
    public func getStandings(
        challengeId: String,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        let params: [String: Any] = [
            "challengeId": challengeId,
            "limit": limit,
            "offset": offset
        ]

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("challenge_standings_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "challenge_standings" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("challenge_standings_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("challenge_standings_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("challenge_standings", data: params)
        }
    }

    /// Query achievement state for the current player.
    ///
    /// - Parameter achievementId: Optional achievement to scope the query to; omit to return all.
    public func getAchievements(achievementId: String? = nil) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        var params: [String: Any] = [:]
        if let achievementId = achievementId {
            params["achievementId"] = achievementId
        }

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("achievement_state", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "achievement_query" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("achievement_state", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("achievement_state", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("achievement_query", data: params)
        }
    }

    /// Send a directed challenge invite to another user.
    ///
    /// The invitee receives a `challenge_invited` broadcast; subscribe with
    /// `client.on("challenge_invited", ...)`.
    ///
    /// - Parameters:
    ///   - toUserId: The recipient user id.
    ///   - type: Invite type. Defaults to "match".
    ///   - payload: Optional custom payload (<= 8KB).
    ///   - ttl: Time-to-live in seconds. Defaults to 300.
    ///   - channel: Optional channel to scope the invite to.
    ///   - inviteId: Optional caller-supplied invite id.
    public func sendChallengeInvite(
        toUserId: String,
        type: String = "match",
        payload: [String: Any]? = nil,
        ttl: Int = 300,
        channel: String? = nil,
        inviteId: String? = nil
    ) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        var params: [String: Any] = [
            "toUserId": toUserId,
            "type": type,
            "ttl": ttl
        ]
        if let payload = payload {
            params["payload"] = payload
        }
        if let channel = channel {
            params["channel"] = channel
        }
        if let inviteId = inviteId {
            params["inviteId"] = inviteId
        }

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("challenge_invite_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "challenge_invite" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("challenge_invite_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("challenge_invite_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("challenge_invite", data: params)
        }
    }

    /// Reply to a directed challenge invite.
    ///
    /// - Parameters:
    ///   - inviteId: The invite id from the `challenge_invited` broadcast.
    ///   - accept: Whether the invite is accepted.
    ///   - reason: Optional reason (e.g. for a decline).
    public func replyChallengeInvite(
        inviteId: String,
        accept: Bool,
        reason: String? = nil
    ) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        var params: [String: Any] = [
            "inviteId": inviteId,
            "accept": accept
        ]
        if let reason = reason {
            params["reason"] = reason
        }

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("challenge_reply_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "challenge_reply" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("challenge_reply_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("challenge_reply_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("challenge_reply", data: params)
        }
    }

    /// Cancel a directed challenge invite the current user sent.
    ///
    /// - Parameter inviteId: The invite id to cancel.
    public func cancelChallengeInvite(inviteId: String) async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        let params: [String: Any] = [
            "inviteId": inviteId
        ]

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("challenge_invite_cancel_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "challenge_invite_cancel" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("challenge_invite_cancel_success", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("challenge_invite_cancel_success", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("challenge_invite_cancel", data: params)
        }
    }

    /// Query the current user's pending challenge invites.
    public func getChallengeInvites() async throws -> [String: Any] {
        guard let client = client, client.isConnected else {
            throw OddSocketsError.notConnected
        }

        return try await withCheckedThrowingContinuation { continuation in
            var successHandler: ((Any) -> Void)?
            var errorHandler: ((Any) -> Void)?

            successHandler = { data in
                if let result = data as? [String: Any] {
                    continuation.resume(returning: result)
                }
                client.off("challenge_invites", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            errorHandler = { data in
                if let error = data as? [String: Any],
                   let event = error["event"] as? String,
                   event == "challenge_invites_query" {
                    let message = error["message"] as? String ?? "Unknown error"
                    continuation.resume(throwing: OddSocketsError.serverError(message))
                }
                client.off("challenge_invites", handler: successHandler!)
                client.off("error", handler: errorHandler!)
            }

            client.once("challenge_invites", handler: successHandler!)
            client.once("error", handler: errorHandler!)
            client.emit("challenge_invites_query", data: [String: Any]())
        }
    }
}
