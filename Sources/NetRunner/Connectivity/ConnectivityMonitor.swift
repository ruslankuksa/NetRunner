
import Foundation

/// Waits for network connectivity to become available.
public protocol ConnectivityMonitor: Sendable {
    /// Suspends until connectivity is available.
    ///
    /// - Parameter timeout: Maximum time to wait, or `nil` to wait indefinitely.
    func waitUntilConnected(timeout: TimeInterval?) async throws
}
