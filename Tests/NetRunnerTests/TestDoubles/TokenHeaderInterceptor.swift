import Foundation
@testable import NetRunner

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
