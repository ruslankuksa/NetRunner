@testable import NetRunner

final class RefreshTokenRetryInterceptor: RetryInterceptor, @unchecked Sendable {
    private let store: RetryTokenStore
    var callCount = 0

    init(store: RetryTokenStore) {
        self.store = store
    }

    func retryDecision(for context: RetryContext) async -> RetryDecision {
        callCount += 1
        store.token = "refreshed"
        return .retry
    }
}
