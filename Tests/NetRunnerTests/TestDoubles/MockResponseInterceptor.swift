
import Foundation
@testable import NetRunner

// MARK: - Thread Safety
// @unchecked Sendable is safe here because:
// 1. Each test creates its own instance (no cross-test sharing)
// 2. Configuration happens before the actor call (sequential)
// 3. Assertions happen after `await` returns (happens-before barrier)
final class MockResponseInterceptor: ResponseInterceptor, @unchecked Sendable {
    var shouldRetryResult: Bool
    var callCount = 0

    init(shouldRetryResult: Bool = true) {
        self.shouldRetryResult = shouldRetryResult
    }

    func shouldRetry(context: RetryContext) async -> Bool {
        callCount += 1
        return shouldRetryResult
    }
}
