
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
        NetworkError.unauthorized,
        NetworkError.timeout,
        NetworkError.noConnectivity,
        NetworkError.serverError(statusCode: 503),
        NetworkError.clientError(statusCode: 404),
    ])
    func errorDescriptionNonNil(error: NetworkError) {
        #expect(error.errorDescription != nil, "\(error) should have a non-nil description")
    }

    // MARK: - validate status dispatch (via NetRunner default)

    @Test func validate200DoesNotThrow() throws {
        let runner = TestRunner()
        let response = makeHTTPResponse(statusCode: 200)
        #expect(throws: Never.self) { try runner.validate(response) }
    }

    @Test func validate299DoesNotThrow() throws {
        let runner = TestRunner()
        #expect(throws: Never.self) { try runner.validate(makeHTTPResponse(statusCode: 299)) }
    }

    @Test func validate401ThrowsUnauthorized() {
        let runner = TestRunner()
        #expect(throws: NetworkError.unauthorized) {
            try runner.validate(makeHTTPResponse(statusCode: 401))
        }
    }

    @Test func validate404ThrowsClientError() {
        let runner = TestRunner()
        #expect(throws: NetworkError.clientError(statusCode: 404)) {
            try runner.validate(makeHTTPResponse(statusCode: 404))
        }
    }

    @Test func validate503ThrowsServerError() {
        let runner = TestRunner()
        #expect(throws: NetworkError.serverError(statusCode: 503)) {
            try runner.validate(makeHTTPResponse(statusCode: 503))
        }
    }

    @Test func validateNonHTTPThrowsInvalidResponse() {
        let runner = TestRunner()
        let response = URLResponse(url: URL(string: "https://example.com")!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        #expect(throws: NetworkError.invalidResponse) {
            try runner.validate(response)
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
