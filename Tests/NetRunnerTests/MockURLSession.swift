
import Foundation
@testable import NetRunner

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
