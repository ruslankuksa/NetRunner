import Foundation

/// Defines retry behavior for failed network requests.
public struct RetryPolicy: Sendable {
    enum Storage: Sendable {
        case none
        case fixed(maxRetries: Int, delay: TimeInterval, retryableMethods: Set<HTTPMethod>)
        case exponential(maxRetries: Int, baseDelay: TimeInterval, retryableMethods: Set<HTTPMethod>)
    }

    let storage: Storage

    private init(storage: Storage) {
        self.storage = storage
    }
}

public extension RetryPolicy {
    /// No retries.
    static let none = RetryPolicy(storage: .none)

    /// Retries allowed HTTP methods up to `maxRetries` times with a constant delay between attempts.
    static func fixed(
        maxRetries: Int,
        delay: TimeInterval,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    ) -> RetryPolicy {
        RetryPolicy(
            storage: .fixed(
                maxRetries: normalizedRetryCount(maxRetries),
                delay: normalizedDelay(delay),
                retryableMethods: retryableMethods
            )
        )
    }

    /// Retries allowed HTTP methods up to `maxRetries` times with exponentially increasing delays.
    static func exponential(
        maxRetries: Int,
        baseDelay: TimeInterval,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    ) -> RetryPolicy {
        RetryPolicy(
            storage: .exponential(
                maxRetries: normalizedRetryCount(maxRetries),
                baseDelay: normalizedDelay(baseDelay),
                retryableMethods: retryableMethods
            )
        )
    }

    /// Number of retries after the initial request attempt.
    var maxRetries: Int {
        switch storage {
        case .none:
            return 0
        case .fixed(let maxRetries, _, _):
            return maxRetries
        case .exponential(let maxRetries, _, _):
            return maxRetries
        }
    }

    /// HTTP methods eligible for automatic retries.
    var retryableMethods: Set<HTTPMethod> {
        switch storage {
        case .none:
            return []
        case .fixed(_, _, let retryableMethods):
            return retryableMethods
        case .exponential(_, _, let retryableMethods):
            return retryableMethods
        }
    }

    /// Returns the delay in seconds for the given attempt index (0-based).
    func delay(forAttempt attempt: Int) -> TimeInterval {
        switch storage {
        case .none:
            return 0
        case .fixed(_, let delay, _):
            return delay
        case .exponential(_, let baseDelay, _):
            let multiplier = pow(2.0, Double(attempt))
            return baseDelay * multiplier
        }
    }

    /// Returns whether the given error is eligible for retry.
    func isRetryable(error: NetworkError) -> Bool {
        switch error {
        case .timeout, .noConnectivity, .serverError:
            return true
        default:
            return false
        }
    }

    /// Returns whether the given error and HTTP method are eligible for retry.
    func isRetryable(error: NetworkError, method: HTTPMethod?) -> Bool {
        guard let method else {
            return false
        }
        return isRetryable(error: error) && retryableMethods.contains(method)
    }

    @available(*, deprecated, renamed: "fixed(maxRetries:delay:retryableMethods:)")
    static func fixed(
        maxAttempts: Int,
        delay: TimeInterval,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    ) -> RetryPolicy {
        fixed(maxRetries: maxAttempts, delay: delay, retryableMethods: retryableMethods)
    }

    @available(*, deprecated, renamed: "exponential(maxRetries:baseDelay:retryableMethods:)")
    static func exponential(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    ) -> RetryPolicy {
        exponential(maxRetries: maxAttempts, baseDelay: baseDelay, retryableMethods: retryableMethods)
    }

    @available(*, deprecated, renamed: "maxRetries")
    var maxAttempts: Int {
        maxRetries
    }

    private static func normalizedRetryCount(_ value: Int) -> Int {
        max(0, value)
    }

    private static func normalizedDelay(_ value: TimeInterval) -> TimeInterval {
        value.isFinite ? max(0, value) : 0
    }
}
