import Foundation

/// Base error type for all OddSockets-related errors.
public enum OddSocketsError: Error, LocalizedError, CustomStringConvertible {
    /// Invalid configuration error.
    case invalidConfiguration(String)
    
    /// Connection-related error.
    case connectionError(String, code: String? = nil)
    
    /// Authentication-related error.
    case authenticationError(String, code: String? = nil)
    
    /// Channel-related error.
    case channelError(String, channel: String? = nil, code: String? = nil)
    
    /// Message-related error.
    case messageError(String, messageId: String? = nil, code: String? = nil)
    
    /// Message too large error.
    case messageTooLarge(String)
    
    /// Network-related error.
    case networkError(String, underlyingError: Error? = nil)
    
    /// Timeout error.
    case timeout(String)
    
    /// Generic error with custom code and details.
    case generic(String, code: String? = nil, details: [String: Any]? = nil)
    
    // MARK: - LocalizedError
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid Configuration: \(message)"
        case .connectionError(let message, _):
            return "Connection Error: \(message)"
        case .authenticationError(let message, _):
            return "Authentication Error: \(message)"
        case .channelError(let message, let channel, _):
            if let channel = channel {
                return "Channel Error (\(channel)): \(message)"
            } else {
                return "Channel Error: \(message)"
            }
        case .messageError(let message, let messageId, _):
            if let messageId = messageId {
                return "Message Error (\(messageId)): \(message)"
            } else {
                return "Message Error: \(message)"
            }
        case .messageTooLarge(let message):
            return "Message Too Large: \(message)"
        case .networkError(let message, let underlyingError):
            if let underlyingError = underlyingError {
                return "Network Error: \(message) - \(underlyingError.localizedDescription)"
            } else {
                return "Network Error: \(message)"
            }
        case .timeout(let message):
            return "Timeout: \(message)"
        case .generic(let message, _, _):
            return message
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .invalidConfiguration:
            return "The provided configuration is invalid or incomplete."
        case .connectionError:
            return "Failed to establish or maintain connection to OddSockets."
        case .authenticationError:
            return "Authentication with OddSockets failed."
        case .channelError:
            return "Channel operation failed."
        case .messageError:
            return "Message operation failed."
        case .messageTooLarge:
            return "Message exceeds maximum allowed size."
        case .networkError:
            return "Network communication failed."
        case .timeout:
            return "Operation timed out."
        case .generic:
            return "An error occurred."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .invalidConfiguration:
            return "Please check your configuration parameters and ensure all required fields are provided."
        case .connectionError:
            return "Check your network connection and ensure the OddSockets service is available."
        case .authenticationError:
            return "Verify your API key is correct and has the necessary permissions."
        case .channelError:
            return "Ensure the channel name is valid and you have permission to access it."
        case .messageError:
            return "Check the message format and try again."
        case .messageTooLarge:
            return "Reduce the message size to under 32KB and try again."
        case .networkError:
            return "Check your network connection and try again."
        case .timeout:
            return "Try again or increase the timeout value."
        case .generic:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    // MARK: - CustomStringConvertible
    
    public var description: String {
        return errorDescription ?? "Unknown OddSockets error"
    }
    
    // MARK: - Error Code
    
    /// The error code associated with this error.
    public var code: String {
        switch self {
        case .invalidConfiguration:
            return ErrorCodes.invalidConfiguration
        case .connectionError(_, let code):
            return code ?? ErrorCodes.connectionFailed
        case .authenticationError(_, let code):
            return code ?? ErrorCodes.authenticationFailed
        case .channelError(_, _, let code):
            return code ?? ErrorCodes.channelAccessDenied
        case .messageError(_, _, let code):
            return code ?? ErrorCodes.messageDeliveryFailed
        case .messageTooLarge:
            return "MESSAGE_TOO_LARGE"
        case .networkError:
            return ErrorCodes.connectionFailed
        case .timeout:
            return ErrorCodes.operationTimeout
        case .generic(_, let code, _):
            return code ?? "UNKNOWN_ERROR"
        }
    }
    
    // MARK: - Additional Properties
    
    /// The channel name associated with this error (if applicable).
    public var channelName: String? {
        switch self {
        case .channelError(_, let channel, _):
            return channel
        default:
            return nil
        }
    }
    
    /// The message ID associated with this error (if applicable).
    public var messageId: String? {
        switch self {
        case .messageError(_, let messageId, _):
            return messageId
        default:
            return nil
        }
    }
    
    /// Additional details about the error (if applicable).
    public var details: [String: Any]? {
        switch self {
        case .generic(_, _, let details):
            return details
        default:
            return nil
        }
    }
    
    /// The underlying error (if applicable).
    public var underlyingError: Error? {
        switch self {
        case .networkError(_, let underlyingError):
            return underlyingError
        default:
            return nil
        }
    }
}

// MARK: - Convenience Initializers

extension OddSocketsError {
    /// Creates an invalid API key error.
    public static func invalidApiKey(_ message: String = "Invalid API key format") -> OddSocketsError {
        return .authenticationError(message, code: ErrorCodes.invalidApiKey)
    }
    
    /// Creates a connection failed error.
    public static func connectionFailed(_ message: String = "Failed to connect to OddSockets") -> OddSocketsError {
        return .connectionError(message, code: ErrorCodes.connectionFailed)
    }
    
    /// Creates an authentication failed error.
    public static func authenticationFailed(_ message: String = "Authentication failed") -> OddSocketsError {
        return .authenticationError(message, code: ErrorCodes.authenticationFailed)
    }
    
    /// Creates a channel access denied error.
    public static func channelAccessDenied(_ channel: String, message: String = "Access denied") -> OddSocketsError {
        return .channelError(message, channel: channel, code: ErrorCodes.channelAccessDenied)
    }
    
    /// Creates a message delivery failed error.
    public static func messageDeliveryFailed(_ messageId: String? = nil, message: String = "Message delivery failed") -> OddSocketsError {
        return .messageError(message, messageId: messageId, code: ErrorCodes.messageDeliveryFailed)
    }
    
    /// Creates a worker assignment failed error.
    public static func workerAssignmentFailed(_ message: String = "Worker assignment failed") -> OddSocketsError {
        return .connectionError(message, code: ErrorCodes.workerAssignmentFailed)
    }
    
    /// Creates a max reconnect attempts reached error.
    public static func maxReconnectAttemptsReached(_ attempts: Int) -> OddSocketsError {
        return .connectionError("Maximum reconnection attempts (\(attempts)) reached", code: ErrorCodes.maxReconnectAttemptsReached)
    }
    
    /// Creates an operation timeout error.
    public static func operationTimeout(_ operation: String = "Operation") -> OddSocketsError {
        return .timeout("\(operation) timed out")
    }
    
    /// Creates an invalid channel name error.
    public static func invalidChannelName(_ name: String) -> OddSocketsError {
        return .channelError("Invalid channel name: '\(name)'", channel: name, code: ErrorCodes.invalidChannelName)
    }
}

// MARK: - Error Conversion

extension OddSocketsError {
    /// Creates an OddSocketsError from a generic Error.
    /// - Parameter error: The error to convert
    /// - Returns: An OddSocketsError instance
    public static func from(_ error: Error) -> OddSocketsError {
        if let oddSocketsError = error as? OddSocketsError {
            return oddSocketsError
        }
        
        // Handle common Foundation errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout("Network request timed out")
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkError("No internet connection", underlyingError: error)
            case .cannotConnectToHost, .cannotFindHost:
                return .connectionError("Cannot connect to server", code: ErrorCodes.connectionFailed)
            default:
                return .networkError("Network error: \(urlError.localizedDescription)", underlyingError: error)
            }
        }
        
        // Handle JSON decoding errors
        if error is DecodingError {
            return .generic("Failed to decode response", code: "DECODE_ERROR", details: ["underlying_error": error.localizedDescription])
        }
        
        // Handle JSON encoding errors
        if error is EncodingError {
            return .generic("Failed to encode request", code: "ENCODE_ERROR", details: ["underlying_error": error.localizedDescription])
        }
        
        // Generic error fallback
        return .generic(error.localizedDescription, code: "UNKNOWN_ERROR", details: ["underlying_error": String(describing: error)])
    }
}

// MARK: - Result Extensions

extension Result where Failure == OddSocketsError {
    /// Creates a failure result from a generic error.
    /// - Parameter error: The error to convert
    /// - Returns: A failure result with OddSocketsError
    public static func failure(_ error: Error) -> Result<Success, OddSocketsError> {
        return .failure(OddSocketsError.from(error))
    }
}

// MARK: - Equatable Conformance

extension OddSocketsError: Equatable {
    public static func == (lhs: OddSocketsError, rhs: OddSocketsError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidConfiguration(let lhsMessage), .invalidConfiguration(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.connectionError(let lhsMessage, let lhsCode), .connectionError(let rhsMessage, let rhsCode)):
            return lhsMessage == rhsMessage && lhsCode == rhsCode
        case (.authenticationError(let lhsMessage, let lhsCode), .authenticationError(let rhsMessage, let rhsCode)):
            return lhsMessage == rhsMessage && lhsCode == rhsCode
        case (.channelError(let lhsMessage, let lhsChannel, let lhsCode), .channelError(let rhsMessage, let rhsChannel, let rhsCode)):
            return lhsMessage == rhsMessage && lhsChannel == rhsChannel && lhsCode == rhsCode
        case (.messageError(let lhsMessage, let lhsMessageId, let lhsCode), .messageError(let rhsMessage, let rhsMessageId, let rhsCode)):
            return lhsMessage == rhsMessage && lhsMessageId == rhsMessageId && lhsCode == rhsCode
        case (.messageTooLarge(let lhsMessage), .messageTooLarge(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.networkError(let lhsMessage, _), .networkError(let rhsMessage, _)):
            return lhsMessage == rhsMessage
        case (.timeout(let lhsMessage), .timeout(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.generic(let lhsMessage, let lhsCode, _), .generic(let rhsMessage, let rhsCode, _)):
            return lhsMessage == rhsMessage && lhsCode == rhsCode
        default:
            return false
        }
    }
}

// MARK: - Hashable Conformance

extension OddSocketsError: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
        hasher.combine(errorDescription)
    }
}
