import Foundation

/// Defines how `NetworkClient` handles requests that fail because connectivity
/// is unavailable.
public struct ConnectivityRetryPolicy: Sendable {
    enum Storage: Sendable {
        case disabled
        case waitUntilConnected(
            maxRetries: Int,
            timeout: TimeInterval?,
            retryableMethods: Set<HTTPMethod>
        )
    }

    let storage: Storage

    private init(storage: Storage) {
        self.storage = storage
    }
}

public extension ConnectivityRetryPolicy {
    /// Do not wait for connectivity; use `RetryPolicy` behavior only.
    static let disabled = ConnectivityRetryPolicy(storage: .disabled)

    /// Waits until connectivity is restored before retrying `.noConnectivity`
    /// failures for allowed HTTP methods.
    ///
    /// - Parameters:
    ///   - maxRetries: Number of retries after the initial no-connectivity failure.
    ///   - timeout: Maximum time to wait for each connectivity restoration attempt, or `nil` to wait indefinitely.
    ///   - retryableMethods: HTTP methods eligible for automatic connectivity retry.
    static func waitUntilConnected(
        maxRetries: Int,
        timeout: TimeInterval?,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    ) -> ConnectivityRetryPolicy {
        ConnectivityRetryPolicy(
            storage: .waitUntilConnected(
                maxRetries: normalizedRetryCount(maxRetries),
                timeout: normalizedTimeout(timeout),
                retryableMethods: retryableMethods
            )
        )
    }

    /// Number of connectivity retries after the initial no-connectivity failure.
    var maxRetries: Int {
        switch storage {
        case .disabled:
            return 0
        case .waitUntilConnected(let maxRetries, _, _):
            return maxRetries
        }
    }

    /// Timeout for each connectivity restoration wait.
    var timeout: TimeInterval? {
        switch storage {
        case .disabled:
            return nil
        case .waitUntilConnected(_, let timeout, _):
            return timeout
        }
    }

    /// HTTP methods eligible for automatic connectivity retry.
    var retryableMethods: Set<HTTPMethod> {
        switch storage {
        case .disabled:
            return []
        case .waitUntilConnected(_, _, let retryableMethods):
            return retryableMethods
        }
    }

    /// Whether this policy can perform a connectivity wait.
    var isEnabled: Bool {
        maxRetries > 0
    }

    @available(*, deprecated, renamed: "waitUntilConnected(maxRetries:timeout:retryableMethods:)")
    static func waitUntilConnected(
        maxAttempts: Int,
        timeout: TimeInterval?,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    ) -> ConnectivityRetryPolicy {
        waitUntilConnected(maxRetries: maxAttempts, timeout: timeout, retryableMethods: retryableMethods)
    }

    @available(*, deprecated, renamed: "maxRetries")
    var maxAttempts: Int {
        maxRetries
    }

    private static func normalizedRetryCount(_ value: Int) -> Int {
        max(0, value)
    }

    private static func normalizedTimeout(_ value: TimeInterval?) -> TimeInterval? {
        guard let value else {
            return nil
        }
        return value.isFinite ? max(0, value) : 0
    }
}
