
import Foundation
@testable import NetRunner

// MARK: - Thread Safety
// @unchecked Sendable is safe here because:
// 1. Each test creates its own instance (no cross-test sharing).
// 2. Stubs are configured before the first `await` and not mutated afterwards.
// 3. Sequential result queues are consumed by a single client operation.
// 4. Retry tests await each upload sequentially within a single Task on the
//    `UploadTests` `@Suite(.serialized)` suite, so `capturedRequests` and the
//    `capturedUpload*` arrays are appended-to from one logical thread at a time.
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var capturedRequests: [URLRequest] = []
    var callCount: Int { capturedRequests.count }
    var capturedUploadFileURLs: [URL] = []
    var capturedUploadFileData: [Data] = []
    var uploadProgressEvents: [(bytesSent: Int64, totalBytesExpectedToSend: Int64)] = []
    var dataResults: [Result<(Data, URLResponse), Error>] = []
    var uploadResults: [Result<(Data, URLResponse), Error>] = []

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
        if !dataResults.isEmpty {
            return try dataResults.removeFirst().get()
        }
        if let error = stubbedError {
            throw error
        }
        return (stubbedData, stubbedResponse)
    }

    func upload(
        for request: URLRequest,
        fromFile fileURL: URL,
        progress: @escaping UploadProgressHandler
    ) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        capturedUploadFileURLs.append(fileURL)
        // Read the upload file synchronously here so tests that assert on
        // `capturedUploadFileData` see the bytes before NetworkClient's
        // `defer` removes the multipart temp file.
        if let data = try? Data(contentsOf: fileURL) {
            capturedUploadFileData.append(data)
        }
        for event in uploadProgressEvents {
            progress(event.bytesSent, event.totalBytesExpectedToSend)
        }
        if !uploadResults.isEmpty {
            return try uploadResults.removeFirst().get()
        }
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
