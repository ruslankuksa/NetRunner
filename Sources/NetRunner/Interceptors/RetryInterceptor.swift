/// A retry decision returned by a `RetryInterceptor`.
public enum RetryDecision: Equatable, Sendable {
    /// Allow the retry.
    case retry
    /// Stop retrying and rethrow the current error.
    case doNotRetry
}

/// Decides whether a failed request attempt should be retried.
public protocol RetryInterceptor: Sendable {
    func retryDecision(for context: RetryContext) async -> RetryDecision
}
