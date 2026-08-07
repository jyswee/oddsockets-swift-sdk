import Foundation

/// Resolves the manager endpoint the client asks for a worker assignment.
///
/// The resolved URL is used verbatim. There is deliberately no fallback to the
/// public endpoint when a configured manager is unreachable: silently
/// redirecting a self-hosted or staging deployment at production would make a
/// misconfigured client look healthy, and would invalidate any test aimed at a
/// non-production manager.
internal final class ManagerDiscovery {

    // MARK: - Constants

    /// Environment variable consulted when no manager URL was configured.
    static let environmentVariableName = "ODDSOCKETS_MANAGER_URL"

    /// The endpoint used only when nothing at all was configured.
    static let defaultManagerUrl = "https://connect.oddsockets.tyga.network"

    // MARK: - Properties

    private let managerUrl: String

    // MARK: - Initialization

    /// Creates a discovery service for the caller's configured manager URL.
    /// - Parameter configuredUrl: The manager URL from the client configuration.
    ///   `nil`, empty and whitespace-only values count as "not configured".
    /// - Throws: `OddSocketsError.invalidConfiguration` if the resolved URL is
    ///   not an absolute `http://` or `https://` URL
    init(configuredUrl: String?) throws {
        self.managerUrl = try ManagerDiscovery.resolveManagerUrl(configuredUrl: configuredUrl)
    }

    // MARK: - Public Methods

    /// Returns the manager URL this instance was built with.
    /// - Returns: The manager URL, without trailing slashes
    func discoverManagerUrl() -> String {
        return managerUrl
    }

    // MARK: - Resolution

    /// Resolves the manager URL to use.
    ///
    /// Precedence is explicit configuration, then the `ODDSOCKETS_MANAGER_URL`
    /// environment variable, then `defaultManagerUrl`. The default only applies
    /// when nothing at all was configured.
    /// - Parameter configuredUrl: The manager URL from the client configuration
    /// - Returns: The validated manager URL, without trailing slashes
    /// - Throws: `OddSocketsError.invalidConfiguration` if the resolved URL is
    ///   not an absolute `http://` or `https://` URL
    static func resolveManagerUrl(configuredUrl: String?) throws -> String {
        let configured = configuredUrl?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let configured, !configured.isEmpty {
            return try validate(configured)
        }

        return try validate(resolvedDefaultManagerUrl())
    }

    /// Returns the manager URL to use when the caller configured none.
    /// - Returns: The `ODDSOCKETS_MANAGER_URL` value if set, otherwise `defaultManagerUrl`
    static func resolvedDefaultManagerUrl() -> String {
        let fromEnvironment = ProcessInfo.processInfo
            .environment[environmentVariableName]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let fromEnvironment, !fromEnvironment.isEmpty {
            return fromEnvironment
        }

        return defaultManagerUrl
    }

    /// Validates a manager URL and strips any trailing slashes.
    /// - Parameter value: The manager URL to validate
    /// - Returns: The manager URL, without trailing slashes
    /// - Throws: `OddSocketsError.invalidConfiguration` if `value` is not an
    ///   absolute `http://` or `https://` URL
    static func validate(_ value: String) throws -> String {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host,
              !host.isEmpty else {
            throw OddSocketsError.invalidConfiguration("Invalid managerUrl: \(value)")
        }

        return normalized
    }
}
