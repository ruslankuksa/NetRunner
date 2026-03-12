
import XCTest
@testable import NetRunner

final class RetryPolicyTests: XCTestCase {

    // MARK: - maxAttempts

    func testMaxAttempts_none_isZero() {
        XCTAssertEqual(RetryPolicy.none.maxAttempts, 0)
    }

    func testMaxAttempts_fixed() {
        XCTAssertEqual(RetryPolicy.fixed(maxAttempts: 3, delay: 1).maxAttempts, 3)
    }

    func testMaxAttempts_exponential() {
        XCTAssertEqual(RetryPolicy.exponential(maxAttempts: 5, baseDelay: 0.5).maxAttempts, 5)
    }

    // MARK: - delay

    func testDelay_none_isZero() {
        XCTAssertEqual(RetryPolicy.none.delay(forAttempt: 0), 0)
    }

    func testDelay_fixed_isConstant() {
        let policy = RetryPolicy.fixed(maxAttempts: 3, delay: 2.0)
        XCTAssertEqual(policy.delay(forAttempt: 0), 2.0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(policy.delay(forAttempt: 2), 2.0)
    }

    func testDelay_exponential_doubles() {
        let policy = RetryPolicy.exponential(maxAttempts: 3, baseDelay: 1.0)
        // attempt 0: 1.0 * 2^0 = 1s
        // attempt 1: 1.0 * 2^1 = 2s
        // attempt 2: 1.0 * 2^2 = 4s
        XCTAssertEqual(policy.delay(forAttempt: 0), 1.0)
        XCTAssertEqual(policy.delay(forAttempt: 1), 2.0)
        XCTAssertEqual(policy.delay(forAttempt: 2), 4.0)
    }

    func testDelay_exponential_zeroBaseDelay_isZero() {
        let policy = RetryPolicy.exponential(maxAttempts: 3, baseDelay: 0)
        XCTAssertEqual(policy.delay(forAttempt: 0), 0)
        XCTAssertEqual(policy.delay(forAttempt: 2), 0)
    }

    // MARK: - isRetryable

    func testIsRetryable_timeout_isTrue() {
        XCTAssertTrue(RetryPolicy.fixed(maxAttempts: 3, delay: 0).isRetryable(error: .timeout))
    }

    func testIsRetryable_noConnectivity_isTrue() {
        XCTAssertTrue(RetryPolicy.fixed(maxAttempts: 3, delay: 0).isRetryable(error: .noConnectivity))
    }

    func testIsRetryable_serverError_isTrue() {
        XCTAssertTrue(RetryPolicy.fixed(maxAttempts: 3, delay: 0).isRetryable(error: .serverError(statusCode: 503)))
    }

    func testIsRetryable_clientError_isFalse() {
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).isRetryable(error: .clientError(statusCode: 404)))
    }

    func testIsRetryable_unauthorized_isFalse() {
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).isRetryable(error: .unauthorized))
    }

    func testIsRetryable_decodeError_isFalse() {
        let decodeErr = NetworkError.decodingFailed(NSError(domain: "d", code: 1))
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).isRetryable(error: decodeErr))
    }

    func testIsRetryable_invalidURL_isFalse() {
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).isRetryable(error: .invalidURL))
    }
}
