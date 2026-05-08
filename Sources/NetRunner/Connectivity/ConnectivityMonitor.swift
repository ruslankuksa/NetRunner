
import Foundation

/// Waits for network connectivity to become available.
public protocol ConnectivityMonitor: Sendable {
    /// Suspends until connectivity is available.
    ///
    /// - Parameter timeout: Maximum time to wait, or `nil` to wait indefinitely.
    func waitUntilConnected(timeout: TimeInterval?) async throws

    /// Suspends until a future connectivity restoration is observed.
    ///
    /// Implementations that can distinguish current state from a future
    /// restoration should wait for the next connected update. Simpler monitors
    /// can use the default implementation, which delegates to
    /// `waitUntilConnected(timeout:)`.
    ///
    /// - Parameter timeout: Maximum time to wait, or `nil` to wait indefinitely.
    func waitForConnectivityRestoration(timeout: TimeInterval?) async throws
}

public extension ConnectivityMonitor {
    func waitForConnectivityRestoration(timeout: TimeInterval?) async throws {
        try await waitUntilConnected(timeout: timeout)
    }
}
