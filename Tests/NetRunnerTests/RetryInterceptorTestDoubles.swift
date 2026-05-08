
import Foundation
@testable import NetRunner

// MARK: - Thread Safety
// @unchecked Sendable is safe here because tests configure and assert these
// doubles around awaited client calls, and NetRunner invokes them sequentially
// inside a single request or upload operation.
final class RetryTokenStore: @unchecked Sendable {
    var token: String

    init(token: String) {
        self.token = token
    }
}

final class TokenHeaderInterceptor: RequestInterceptor, @unchecked Sendable {
    private let store: RetryTokenStore
    var interceptCallCount = 0

    init(store: RetryTokenStore) {
        self.store = store
    }

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        interceptCallCount += 1
        var modified = request
        modified.setValue("Bearer \(store.token)", forHTTPHeaderField: "Authorization")
        return modified
    }
}

final class RefreshTokenRetryInterceptor: ResponseInterceptor, @unchecked Sendable {
    private let store: RetryTokenStore
    var callCount = 0

    init(store: RetryTokenStore) {
        self.store = store
    }

    func shouldRetry(context: RetryContext) async -> Bool {
        callCount += 1
        store.token = "refreshed"
        return true
    }
}
