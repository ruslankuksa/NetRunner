
import Foundation

/// Intercepts outgoing URL requests before they are sent,
/// allowing modification such as adding authentication headers.
public protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

/// Context passed to a `ResponseInterceptor` when deciding whether to retry a failed request.
public struct RetryContext: Sendable {
    public let request: URLRequest
    /// Zero-based index of the current retry attempt.
    public let attemptIndex: Int
    public let error: NetworkError

    public init(request: URLRequest, attemptIndex: Int, error: NetworkError) {
        self.request = request
        self.attemptIndex = attemptIndex
        self.error = error
    }
}

/// Intercepts responses to decide whether a failed request should be retried.
public protocol ResponseInterceptor: Sendable {
    func shouldRetry(context: RetryContext) async -> Bool
}
