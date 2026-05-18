import Foundation

/// Message size limits (industry standard - matches PubNub)
internal struct MessageSizeLimits {
    static let maxMessageSize = 32768 // 32KB in bytes
    static let maxMessageSizeKB = 32
}

/// Message size validator
internal struct MessageSizeValidator {
    
    /// Validates message size
    /// - Parameter message: Message to validate
    /// - Returns: Message size in bytes
    /// - Throws: `OddSocketsError.messageTooLarge` if message exceeds size limit
    static func validateMessageSize(_ message: Any?) throws -> Int {
        let messageStr: String
        
        if let stringMessage = message as? String {
            messageStr = stringMessage
        } else {
            // Convert to JSON string
            let jsonData = try JSONSerialization.data(withJSONObject: message ?? NSNull())
            messageStr = String(data: jsonData, encoding: .utf8) ?? ""
        }
        
        let messageSize = messageStr.utf8.count
        
        if messageSize > MessageSizeLimits.maxMessageSize {
            let messageSizeKB = Double(messageSize) / 1024.0
            throw OddSocketsError.messageTooLarge(
                "Message size (\(String(format: "%.0f", messageSizeKB))KB) exceeds maximum allowed size of \(MessageSizeLimits.maxMessageSizeKB)KB. " +
                "This limit matches industry standards (PubNub, Socket.IO) for reliable real-time messaging."
            )
        }
        
        return messageSize
    }
}
