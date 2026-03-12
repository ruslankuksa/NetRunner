
import XCTest
@testable import NetRunner

final class NetworkErrorTests: XCTestCase {

    // MARK: - init(_ error:)

    func testInit_timeout() {
        let error = URLError(.timedOut)
        XCTAssertEqual(NetworkError(error), .timeout)
    }

    func testInit_notConnectedToInternet() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(NetworkError(error), .noConnectivity)
    }

    func testInit_networkConnectionLost() {
        let error = URLError(.networkConnectionLost)
        XCTAssertEqual(NetworkError(error), .noConnectivity)
    }

    func testInit_otherURLError_mapsToRequestFailed() {
        let error = URLError(.badURL)
        if case .requestFailed = NetworkError(error) {
            // pass
        } else {
            XCTFail("Expected .requestFailed for unhandled URLError")
        }
    }

    func testInit_nonURLError_mapsToRequestFailed() {
        let error = NSError(domain: "test", code: 42)
        if case .requestFailed = NetworkError(error) {
            // pass
        } else {
            XCTFail("Expected .requestFailed for non-URLError")
        }
    }

    // MARK: - errorDescription

    func testErrorDescription_allCasesNonNil() {
        let errors: [NetworkError] = [
            .invalidURL,
            .requestFailed("oops"),
            .invalidResponse,
            .decodingFailed(NSError(domain: "d", code: 1)),
            .httpBodyNotAllowedForGET,
            .unauthorized,
            .timeout,
            .noConnectivity,
            .serverError(statusCode: 503),
            .clientError(statusCode: 404),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a non-nil description")
        }
    }

    // MARK: - validate status dispatch (via NetRunner default)

    func testValidate_200_doesNotThrow() {
        let runner = TestRunner()
        let response = makeHTTPResponse(statusCode: 200)
        XCTAssertNoThrow(try runner.validate(response))
    }

    func testValidate_299_doesNotThrow() {
        let runner = TestRunner()
        XCTAssertNoThrow(try runner.validate(makeHTTPResponse(statusCode: 299)))
    }

    func testValidate_401_throwsUnauthorized() {
        let runner = TestRunner()
        XCTAssertThrowsError(try runner.validate(makeHTTPResponse(statusCode: 401))) { error in
            XCTAssertEqual(error as? NetworkError, .unauthorized)
        }
    }

    func testValidate_404_throwsClientError() {
        let runner = TestRunner()
        XCTAssertThrowsError(try runner.validate(makeHTTPResponse(statusCode: 404))) { error in
            if case .clientError(let code) = error as? NetworkError {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Expected .clientError(404)")
            }
        }
    }

    func testValidate_503_throwsServerError() {
        let runner = TestRunner()
        XCTAssertThrowsError(try runner.validate(makeHTTPResponse(statusCode: 503))) { error in
            if case .serverError(let code) = error as? NetworkError {
                XCTAssertEqual(code, 503)
            } else {
                XCTFail("Expected .serverError(503)")
            }
        }
    }

    func testValidate_nonHTTP_throwsInvalidResponse() {
        let runner = TestRunner()
        let response = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertThrowsError(try runner.validate(response)) { error in
            XCTAssertEqual(error as? NetworkError, .invalidResponse)
        }
    }

    // MARK: - Helpers

    private func makeHTTPResponse(statusCode: Int) -> URLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

// Minimal conformer so we can call the default validate
private struct TestRunner: NetRunner {
    func execute<T: Decodable>(request: any NetworkRequest) async throws -> T { fatalError() }
    func send(request: any NetworkRequest) async throws { fatalError() }
}
