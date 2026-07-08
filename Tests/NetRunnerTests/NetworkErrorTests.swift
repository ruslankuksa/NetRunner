
import Testing
import Foundation
@testable import NetRunner

struct NetworkErrorTests {

    // MARK: - init(_ error:)

    @Test func initTimeout() {
        let error = URLError(.timedOut)
        #expect(NetworkError(error) == .timeout)
    }

    @Test func initNotConnectedToInternet() {
        let error = URLError(.notConnectedToInternet)
        #expect(NetworkError(error) == .noConnectivity)
    }

    @Test func initNetworkConnectionLost() {
        let error = URLError(.networkConnectionLost)
        #expect(NetworkError(error) == .noConnectivity)
    }

    @Test func initOtherURLErrorMapsToRequestFailed() {
        let error = URLError(.badURL)
        if case .requestFailed = NetworkError(error) {
            // pass
        } else {
            Issue.record("Expected .requestFailed for unhandled URLError")
        }
    }

    @Test func initUnhandledURLErrorPreservesCodeInRequestFailedMessage() throws {
        let error = URLError(.badURL)
        guard case .requestFailed(let message) = NetworkError(error) else {
            Issue.record("Expected .requestFailed for unhandled URLError")
            return
        }

        #expect(message.contains(String(URLError.Code.badURL.rawValue)))
    }

    @Test func initNonURLErrorMapsToRequestFailed() {
        let error = NSError(domain: "test", code: 42)
        if case .requestFailed = NetworkError(error) {
            // pass
        } else {
            Issue.record("Expected .requestFailed for non-URLError")
        }
    }

    // MARK: - errorDescription

    @Test(arguments: [
        NetworkError.invalidURL,
        NetworkError.requestFailed("oops"),
        NetworkError.invalidResponse,
        NetworkError.decodingFailed(NSError(domain: "d", code: 1)),
        NetworkError.httpBodyNotAllowedForGET,
        NetworkError.uploadBodyNotAllowedForGET,
        NetworkError.unauthorized(response: makeTestHTTPErrorResponse(statusCode: 401)),
        NetworkError.timeout,
        NetworkError.noConnectivity,
        NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503)),
        NetworkError.clientError(response: makeTestHTTPErrorResponse(statusCode: 404)),
        NetworkError.unexpectedStatusCode(response: makeTestHTTPErrorResponse(statusCode: 300)),
    ])
    func errorDescriptionNonNil(error: NetworkError) {
        #expect(error.errorDescription != nil, "\(error) should have a non-nil description")
    }

    // MARK: - validate status dispatch (via NetRunner default)

    @Test func validate200DoesNotThrow() throws {
        let runner = TestRunner()
        let response = makeHTTPResponse(statusCode: 200)
        #expect(throws: Never.self) { try runner.validate(response, data: Data()) }
    }

    @Test func validate299DoesNotThrow() throws {
        let runner = TestRunner()
        #expect(throws: Never.self) {
            try runner.validate(makeHTTPResponse(statusCode: 299), data: Data())
        }
    }

    @Test func validate401ThrowsUnauthorized() {
        let runner = TestRunner()
        #expect(throws: NetworkError.unauthorized(response: makeTestHTTPErrorResponse(statusCode: 401))) {
            try runner.validate(makeHTTPResponse(statusCode: 401), data: Data())
        }
    }

    @Test func validate404ThrowsClientError() {
        let runner = TestRunner()
        #expect(throws: NetworkError.clientError(response: makeTestHTTPErrorResponse(statusCode: 404))) {
            try runner.validate(makeHTTPResponse(statusCode: 404), data: Data())
        }
    }

    @Test func validate422ThrowsClientErrorWithBodyAndHeaders() {
        let runner = TestRunner()
        let body = Data(#"{"success":false,"message":["Already connected"]}"#.utf8)
        let response = makeHTTPResponse(
            statusCode: 422,
            headerFields: ["X-Request-ID": "request-123"]
        )

        do {
            try runner.validate(response, data: body)
            Issue.record("Expected validation to throw a client error")
        } catch NetworkError.clientError(let errorResponse) {
            #expect(errorResponse.statusCode == 422)
            #expect(errorResponse.body == body)
            #expect(errorResponse.headers["X-Request-ID"] == "request-123")
            #expect(errorResponse.bodyText() == #"{"success":false,"message":["Already connected"]}"#)
        } catch {
            Issue.record("Expected client error, got \(error)")
        }
    }

    @Test func validate503ThrowsServerError() {
        let runner = TestRunner()
        #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try runner.validate(makeHTTPResponse(statusCode: 503), data: Data())
        }
    }

    @Test func validate300ThrowsUnexpectedStatusCodeWithBodyAndHeaders() {
        let runner = TestRunner()
        let body = Data("use cached response".utf8)
        let response = makeHTTPResponse(
            statusCode: 300,
            headerFields: ["Location": "https://example.com/alternate"]
        )

        do {
            try runner.validate(response, data: body)
            Issue.record("Expected validation to throw an unexpected status code error")
        } catch NetworkError.unexpectedStatusCode(let errorResponse) {
            #expect(errorResponse.statusCode == 300)
            #expect(errorResponse.body == body)
            #expect(errorResponse.headers["Location"] == "https://example.com/alternate")
            #expect(errorResponse.bodyText() == "use cached response")
        } catch {
            Issue.record("Expected unexpected status code error, got \(error)")
        }
    }

    @Test func validateNonHTTPThrowsInvalidResponse() {
        let runner = TestRunner()
        let response = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        #expect(throws: NetworkError.invalidResponse) {
            try runner.validate(response, data: Data())
        }
    }

    // MARK: - Helpers

    private func makeHTTPResponse(
        statusCode: Int,
        headerFields: [String: String]? = nil
    ) -> URLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        )!
    }
}

// Minimal conformer so we can call the default validate
private struct TestRunner: NetRunner {
    func execute<T: Decodable>(request: any NetworkRequest) async throws -> T { fatalError() }
    func execute(request: any NetworkRequest) async throws { fatalError() }
}
