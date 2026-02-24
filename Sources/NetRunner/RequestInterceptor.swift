
import Foundation

public protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest) async throws -> URLRequest
}

public struct RetryContext: Sendable {
    public let request: URLRequest
    public let attemptCount: Int
    public let error: NetworkError

    public init(request: URLRequest, attemptCount: Int, error: NetworkError) {
        self.request = request
        self.attemptCount = attemptCount
        self.error = error
    }
}

public protocol ResponseInterceptor: Sendable {
    func shouldRetry(context: RetryContext) async -> Bool
}
