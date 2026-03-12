
import Foundation
@testable import NetRunner

// MARK: - Thread Safety
// @unchecked Sendable is safe here because:
// 1. Each test creates its own instance (no cross-test sharing)
// 2. Configuration happens before the actor call (sequential)
// 3. Assertions happen after `await` returns (happens-before barrier)
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var capturedRequests: [URLRequest] = []
    var callCount: Int { capturedRequests.count }

    var stubbedData: Data = Data()
    var stubbedResponse: URLResponse = HTTPURLResponse(
        url: URL(string: "https://example.com")!,
        statusCode: 200,
        httpVersion: nil,
        headerFields: nil
    )!
    var stubbedError: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        if let error = stubbedError {
            throw error
        }
        return (stubbedData, stubbedResponse)
    }

    func stub(statusCode: Int) {
        stubbedResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
