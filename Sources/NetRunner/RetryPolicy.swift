
import Foundation

/// Defines the retry behavior for failed network requests.
public enum RetryPolicy: Sendable {
    /// No retries.
    case none
    /// Retries up to `maxAttempts` times with a constant delay between attempts.
    case fixed(maxAttempts: Int, delay: TimeInterval)
    /// Retries up to `maxAttempts` times with exponentially increasing delays.
    case exponential(maxAttempts: Int, baseDelay: TimeInterval)
}

public extension RetryPolicy {

    var maxAttempts: Int {
        switch self {
        case .none:
            return 0
        case .fixed(let maxAttempts, _):
            return maxAttempts
        case .exponential(let maxAttempts, _):
            return maxAttempts
        }
    }

    /// Returns the delay in seconds for the given attempt index (0-based).
    func delay(forAttempt attempt: Int) -> TimeInterval {
        switch self {
        case .none:
            return 0
        case .fixed(_, let delay):
            return delay
        case .exponential(_, let baseDelay):
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
}
