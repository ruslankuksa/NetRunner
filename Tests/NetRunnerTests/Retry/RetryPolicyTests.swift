
import Testing
import Foundation
@testable import NetRunner

struct RetryPolicyTests {

    // MARK: - maxRetries

    @Test func maxRetriesNoneIsZero() {
        #expect(RetryPolicy.none.maxRetries == 0)
    }

    @Test func maxRetriesFixed() {
        #expect(RetryPolicy.fixed(maxRetries: 3, delay: 1).maxRetries == 3)
    }

    @Test func maxRetriesExponential() {
        #expect(RetryPolicy.exponential(maxRetries: 5, baseDelay: 0.5).maxRetries == 5)
    }

    @Test func retryPolicyNormalizesInvalidValues() {
        let fixed = RetryPolicy.fixed(maxRetries: -2, delay: -1)
        let exponential = RetryPolicy.exponential(maxRetries: -3, baseDelay: .infinity)

        #expect(fixed.maxRetries == 0)
        #expect(fixed.delay(forAttempt: 0) == 0)
        #expect(exponential.maxRetries == 0)
        #expect(exponential.delay(forAttempt: 0) == 0)
    }

    @Test func connectivityRetryPolicyNormalizesInvalidValues() {
        let policy = ConnectivityRetryPolicy.waitUntilConnected(
            maxRetries: -1,
            timeout: -Double.infinity
        )

        #expect(policy.maxRetries == 0)
        #expect(policy.timeout == 0)
        #expect(policy.isEnabled == false)
    }

    // MARK: - delay

    @Test func delayNoneIsZero() {
        #expect(RetryPolicy.none.delay(forAttempt: 0) == 0)
    }

    @Test func delayFixedIsConstant() {
        let policy = RetryPolicy.fixed(maxRetries: 3, delay: 2.0)
        #expect(policy.delay(forAttempt: 0) == 2.0)
        #expect(policy.delay(forAttempt: 1) == 2.0)
        #expect(policy.delay(forAttempt: 2) == 2.0)
    }

    @Test func delayExponentialDoubles() {
        let policy = RetryPolicy.exponential(maxRetries: 3, baseDelay: 1.0)
        #expect(policy.delay(forAttempt: 0) == 1.0)
        #expect(policy.delay(forAttempt: 1) == 2.0)
        #expect(policy.delay(forAttempt: 2) == 4.0)
    }

    @Test func delayExponentialZeroBaseDelayIsZero() {
        let policy = RetryPolicy.exponential(maxRetries: 3, baseDelay: 0)
        #expect(policy.delay(forAttempt: 0) == 0)
        #expect(policy.delay(forAttempt: 2) == 0)
    }

    // MARK: - retryable methods

    @Test func defaultRetryableMethodsAreIdempotent() {
        #expect(HTTPMethod.defaultRetryableMethods == [.get, .put, .delete])
    }

    @Test func httpMethodSupportsCustomMethods() {
        #expect(HTTPMethod.custom("propfind").rawValue == "PROPFIND")
        #expect(HTTPMethod(rawValue: " custom ").rawValue == "CUSTOM")
    }

    @Test func fixedRetryPolicyUsesDefaultRetryableMethods() {
        let policy = RetryPolicy.fixed(maxRetries: 1, delay: 0)
        #expect(policy.retryableMethods == HTTPMethod.defaultRetryableMethods)
    }

    @Test func exponentialRetryPolicyUsesCustomRetryableMethods() {
        let policy = RetryPolicy.exponential(
            maxRetries: 1,
            baseDelay: 0,
            retryableMethods: [.post]
        )
        #expect(policy.retryableMethods == [.post])
    }

    // MARK: - isRetryable

    @Test(arguments: [
        (NetworkError.timeout, true),
        (NetworkError.noConnectivity, true),
        (NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503)), true),
        (NetworkError.clientError(response: makeTestHTTPErrorResponse(statusCode: 404)), false),
        (NetworkError.unauthorized(response: makeTestHTTPErrorResponse(statusCode: 401)), false),
        (NetworkError.decodingFailed(NSError(domain: "d", code: 1)), false),
        (NetworkError.invalidURL, false),
    ])
    func isRetryable(error: NetworkError, expected: Bool) {
        let policy = RetryPolicy.fixed(maxRetries: 3, delay: 0)
        #expect(policy.isRetryable(error: error) == expected)
    }

    @Test func isRetryableConsidersHTTPMethod() {
        let policy = RetryPolicy.fixed(maxRetries: 1, delay: 0)

        #expect(policy.isRetryable(error: .timeout, method: .get))
        #expect(policy.isRetryable(error: .timeout, method: .post) == false)
        #expect(policy.isRetryable(error: .timeout, method: nil) == false)
        #expect(policy.isRetryable(
            error: .clientError(response: makeTestHTTPErrorResponse(statusCode: 404)),
            method: .get
        ) == false)
    }
}
