
import Foundation
@testable import NetRunner

// MARK: - Thread Safety
// @unchecked Sendable is safe here because:
// 1. Each test creates its own instance (no cross-test sharing)
// 2. Configuration happens before the async client call (sequential)
// 3. Assertions happen after `await` returns (happens-before barrier)
final class MockRetryInterceptor: RetryInterceptor, @unchecked Sendable {
    var decision: RetryDecision
    var callCount = 0

    init(decision: RetryDecision = .retry) {
        self.decision = decision
    }

    func retryDecision(for context: RetryContext) async -> RetryDecision {
        callCount += 1
        return decision
    }
}
