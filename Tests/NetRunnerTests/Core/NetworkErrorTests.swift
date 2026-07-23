
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
        NetworkError.requestBodyNotAllowedForGET,
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
}
