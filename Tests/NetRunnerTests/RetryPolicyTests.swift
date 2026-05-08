
import Testing
import Foundation
@testable import NetRunner

struct RetryPolicyTests {

    // MARK: - maxAttempts

    @Test func maxAttemptsNoneIsZero() {
        #expect(RetryPolicy.none.maxAttempts == 0)
    }

    @Test func maxAttemptsFixed() {
        #expect(RetryPolicy.fixed(maxAttempts: 3, delay: 1).maxAttempts == 3)
    }

    @Test func maxAttemptsExponential() {
        #expect(RetryPolicy.exponential(maxAttempts: 5, baseDelay: 0.5).maxAttempts == 5)
    }

    // MARK: - delay

    @Test func delayNoneIsZero() {
        #expect(RetryPolicy.none.delay(forAttempt: 0) == 0)
    }

    @Test func delayFixedIsConstant() {
        let policy = RetryPolicy.fixed(maxAttempts: 3, delay: 2.0)
        #expect(policy.delay(forAttempt: 0) == 2.0)
        #expect(policy.delay(forAttempt: 1) == 2.0)
        #expect(policy.delay(forAttempt: 2) == 2.0)
    }

    @Test func delayExponentialDoubles() {
        let policy = RetryPolicy.exponential(maxAttempts: 3, baseDelay: 1.0)
        #expect(policy.delay(forAttempt: 0) == 1.0)
        #expect(policy.delay(forAttempt: 1) == 2.0)
        #expect(policy.delay(forAttempt: 2) == 4.0)
    }

    @Test func delayExponentialZeroBaseDelayIsZero() {
        let policy = RetryPolicy.exponential(maxAttempts: 3, baseDelay: 0)
        #expect(policy.delay(forAttempt: 0) == 0)
        #expect(policy.delay(forAttempt: 2) == 0)
    }

    // MARK: - retryable methods

    @Test func defaultRetryableMethodsAreIdempotent() {
        #expect(HTTPMethod.defaultRetryableMethods == [.get, .put, .delete])
    }

    @Test func fixedRetryPolicyUsesDefaultRetryableMethods() {
        let policy = RetryPolicy.fixed(maxAttempts: 1, delay: 0)
        #expect(policy.retryableMethods == HTTPMethod.defaultRetryableMethods)
    }

    @Test func exponentialRetryPolicyUsesCustomRetryableMethods() {
        let policy = RetryPolicy.exponential(
            maxAttempts: 1,
            baseDelay: 0,
            retryableMethods: [.post]
        )
        #expect(policy.retryableMethods == [.post])
    }

    // MARK: - isRetryable

    @Test(arguments: [
        (NetworkError.timeout, true),
        (NetworkError.noConnectivity, true),
        (NetworkError.serverError(statusCode: 503), true),
        (NetworkError.clientError(statusCode: 404), false),
        (NetworkError.unauthorized, false),
        (NetworkError.decodingFailed(NSError(domain: "d", code: 1)), false),
        (NetworkError.invalidURL, false),
    ])
    func isRetryable(error: NetworkError, expected: Bool) {
        let policy = RetryPolicy.fixed(maxAttempts: 3, delay: 0)
        #expect(policy.isRetryable(error: error) == expected)
    }

    @Test func isRetryableConsidersHTTPMethod() {
        let policy = RetryPolicy.fixed(maxAttempts: 1, delay: 0)

        #expect(policy.isRetryable(error: .timeout, method: .get))
        #expect(!policy.isRetryable(error: .timeout, method: .post))
        #expect(!policy.isRetryable(error: .timeout, method: nil))
        #expect(!policy.isRetryable(error: .clientError(statusCode: 404), method: .get))
    }
}
