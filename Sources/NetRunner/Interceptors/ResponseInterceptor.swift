/// Intercepts responses to decide whether a failed request should be retried.
public protocol ResponseInterceptor: Sendable {
    func shouldRetry(context: RetryContext) async -> Bool
}
