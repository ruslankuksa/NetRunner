
import XCTest
@testable import NetRunner

final class NetworkErrorTests: XCTestCase {

    // MARK: - mapURLError

    func testMapURLError_timeout() {
        let error = URLError(.timedOut)
        XCTAssertEqual(NetworkError.mapURLError(error), .timeout)
    }

    func testMapURLError_notConnectedToInternet() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(NetworkError.mapURLError(error), .noConnectivity)
    }

    func testMapURLError_networkConnectionLost() {
        let error = URLError(.networkConnectionLost)
        XCTAssertEqual(NetworkError.mapURLError(error), .noConnectivity)
    }

    func testMapURLError_otherURLError_mapsToBadRequest() {
        let error = URLError(.badURL)
        if case .badRequest = NetworkError.mapURLError(error) {
            // pass
        } else {
            XCTFail("Expected .badRequest for unhandled URLError")
        }
    }

    func testMapURLError_nonURLError_mapsToBadRequest() {
        let error = NSError(domain: "test", code: 42)
        if case .badRequest = NetworkError.mapURLError(error) {
            // pass
        } else {
            XCTFail("Expected .badRequest for non-URLError")
        }
    }

    // MARK: - errorDescription

    func testErrorDescription_allCasesNonNil() {
        let errors: [NetworkError] = [
            .badURL,
            .badRequest("oops"),
            .badResponse,
            .unableToDecodeResponse(NSError(domain: "d", code: 1)),
            .notAllowedRequest,
            .notAuthorized,
            .timeout,
            .noConnectivity,
            .serverError(statusCode: 503),
            .clientError(statusCode: 404),
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) should have a non-nil description")
        }
    }

    // MARK: - handleResponse status dispatch (via NetRunner default)

    func testHandleResponse_200_doesNotThrow() {
        let runner = TestRunner()
        let response = makeHTTPResponse(statusCode: 200)
        XCTAssertNoThrow(try runner.handleResponse(response))
    }

    func testHandleResponse_299_doesNotThrow() {
        let runner = TestRunner()
        XCTAssertNoThrow(try runner.handleResponse(makeHTTPResponse(statusCode: 299)))
    }

    func testHandleResponse_401_throwsNotAuthorized() {
        let runner = TestRunner()
        XCTAssertThrowsError(try runner.handleResponse(makeHTTPResponse(statusCode: 401))) { error in
            XCTAssertEqual(error as? NetworkError, .notAuthorized)
        }
    }

    func testHandleResponse_404_throwsClientError() {
        let runner = TestRunner()
        XCTAssertThrowsError(try runner.handleResponse(makeHTTPResponse(statusCode: 404))) { error in
            if case .clientError(let code) = error as? NetworkError {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Expected .clientError(404)")
            }
        }
    }

    func testHandleResponse_503_throwsServerError() {
        let runner = TestRunner()
        XCTAssertThrowsError(try runner.handleResponse(makeHTTPResponse(statusCode: 503))) { error in
            if case .serverError(let code) = error as? NetworkError {
                XCTAssertEqual(code, 503)
            } else {
                XCTFail("Expected .serverError(503)")
            }
        }
    }

    func testHandleResponse_nonHTTP_throwsBadResponse() {
        let runner = TestRunner()
        let response = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        XCTAssertThrowsError(try runner.handleResponse(response)) { error in
            XCTAssertEqual(error as? NetworkError, .badResponse)
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

// Minimal conformer so we can call the default handleResponse
private struct TestRunner: NetRunner {
    func execute<T: Decodable>(request: NetworkRequest) async throws -> T { fatalError() }
    func execute(request: NetworkRequest) async throws { fatalError() }
}

