
import Foundation

public enum RetryPolicy: Sendable {
    case none
    case fixed(maxAttempts: Int, delay: TimeInterval)
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

    /// Returns the delay in nanoseconds for the given attempt index (0-based).
    func delayNanoseconds(forAttempt attempt: Int) -> UInt64 {
        switch self {
        case .none:
            return 0
        case .fixed(_, let delay):
            return UInt64(delay * 1_000_000_000)
        case .exponential(_, let baseDelay):
            let multiplier = pow(2.0, Double(attempt))
            return UInt64(baseDelay * multiplier * 1_000_000_000)
        }
    }

    func shouldRetry(error: NetworkError) -> Bool {
        switch error {
        case .timeout, .noConnectivity, .serverError:
            return true
        default:
            return false
        }
    }
}
