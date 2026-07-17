import Foundation

/// Simple Manager Discovery Service
///
/// Always connects to the main manager endpoint which handles
/// all routing and load balancing transparently.
internal class ManagerDiscovery {
    
    // MARK: - Properties
    
    private let managerUrl = "https://connect.oddsockets.tyga.network"
    
    // MARK: - Singleton
    
    static let shared = ManagerDiscovery()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Get the manager URL (always returns the main endpoint)
    /// - Parameter apiKey: The OddSockets API key (not used, kept for compatibility)
    /// - Returns: The manager URL
    func discoverManagerUrl(apiKey: String) async -> String {
        return managerUrl
    }
    
    /// Clear cache (no-op, kept for compatibility)
    func clearCache() {
        // No cache to clear in simplified version
    }
}
