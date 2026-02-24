
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

    // MARK: - delayNanoseconds

    func testDelayNanoseconds_none_isZero() {
        XCTAssertEqual(RetryPolicy.none.delayNanoseconds(forAttempt: 0), 0)
    }

    func testDelayNanoseconds_fixed_isConstant() {
        let policy = RetryPolicy.fixed(maxAttempts: 3, delay: 2.0)
        let expected = UInt64(2.0 * 1_000_000_000)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 0), expected)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 1), expected)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 2), expected)
    }

    func testDelayNanoseconds_exponential_doubles() {
        let policy = RetryPolicy.exponential(maxAttempts: 3, baseDelay: 1.0)
        // attempt 0: 1.0 * 2^0 = 1s
        // attempt 1: 1.0 * 2^1 = 2s
        // attempt 2: 1.0 * 2^2 = 4s
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 0), UInt64(1_000_000_000))
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 1), UInt64(2_000_000_000))
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 2), UInt64(4_000_000_000))
    }

    func testDelayNanoseconds_exponential_zeroBaseDelay_isZero() {
        let policy = RetryPolicy.exponential(maxAttempts: 3, baseDelay: 0)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 0), 0)
        XCTAssertEqual(policy.delayNanoseconds(forAttempt: 2), 0)
    }

    // MARK: - shouldRetry

    func testShouldRetry_timeout_isTrue() {
        XCTAssertTrue(RetryPolicy.fixed(maxAttempts: 3, delay: 0).shouldRetry(error: .timeout))
    }

    func testShouldRetry_noConnectivity_isTrue() {
        XCTAssertTrue(RetryPolicy.fixed(maxAttempts: 3, delay: 0).shouldRetry(error: .noConnectivity))
    }

    func testShouldRetry_serverError_isTrue() {
        XCTAssertTrue(RetryPolicy.fixed(maxAttempts: 3, delay: 0).shouldRetry(error: .serverError(statusCode: 503)))
    }

    func testShouldRetry_clientError_isFalse() {
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).shouldRetry(error: .clientError(statusCode: 404)))
    }

    func testShouldRetry_notAuthorized_isFalse() {
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).shouldRetry(error: .notAuthorized))
    }

    func testShouldRetry_decodeError_isFalse() {
        let decodeErr = NetworkError.unableToDecodeResponse(NSError(domain: "d", code: 1))
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).shouldRetry(error: decodeErr))
    }

    func testShouldRetry_badURL_isFalse() {
        XCTAssertFalse(RetryPolicy.fixed(maxAttempts: 3, delay: 0).shouldRetry(error: .badURL))
    }
}
