@testable import NetRunner

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
