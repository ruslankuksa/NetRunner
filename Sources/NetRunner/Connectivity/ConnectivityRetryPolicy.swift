
import Foundation

/// Defines how `NetworkClient` handles requests that fail because connectivity
/// is unavailable.
public enum ConnectivityRetryPolicy: Sendable {
    /// Do not wait for connectivity; use `RetryPolicy` behavior only.
    case disabled
    /// Waits until connectivity is restored before retrying `.noConnectivity` failures for allowed HTTP methods.
    ///
    /// - Parameters:
    ///   - maxAttempts: Number of retries after the initial no-connectivity failure.
    ///   - timeout: Maximum time to wait for each connectivity restoration attempt, or `nil` to wait indefinitely.
    ///   - retryableMethods: HTTP methods eligible for automatic connectivity retry.
    case waitUntilConnected(
        maxAttempts: Int,
        timeout: TimeInterval?,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    )
}
