
import Foundation

/// Defines the retry behavior for failed network requests.
public enum RetryPolicy: Sendable {
    /// No retries.
    case none
    /// Retries allowed HTTP methods up to `maxAttempts` times with a constant delay between attempts.
    case fixed(
        maxAttempts: Int,
        delay: TimeInterval,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    )
    /// Retries allowed HTTP methods up to `maxAttempts` times with exponentially increasing delays.
    case exponential(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        retryableMethods: Set<HTTPMethod> = HTTPMethod.defaultRetryableMethods
    )
}

public extension RetryPolicy {

    var maxAttempts: Int {
        switch self {
        case .none:
            return 0
        case .fixed(let maxAttempts, _, _):
            return maxAttempts
        case .exponential(let maxAttempts, _, _):
            return maxAttempts
        }
    }

    /// HTTP methods eligible for automatic retries.
    var retryableMethods: Set<HTTPMethod> {
        switch self {
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
        switch self {
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
}
