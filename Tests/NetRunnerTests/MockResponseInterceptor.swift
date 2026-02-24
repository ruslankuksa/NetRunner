
import Foundation
@testable import NetRunner

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
