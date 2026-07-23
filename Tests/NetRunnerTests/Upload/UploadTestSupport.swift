import Foundation
import Testing
@testable import NetRunner

// `multipartPreparationFailureRemovesTemporaryFile` snapshots the contents of
// `FileManager.default.temporaryDirectory` and asserts on `Set` equality, so
// running these tests in parallel with each other (or with other suites that
// touch the temp dir) would produce flakes. Hence `.serialized`.
@Suite(
    .serialized,
    .timeLimit(.minutes(1)),
    .tags(.networking, .filesystem)
)
struct UploadTests {
    enum UploadTestCodingError: Error, Sendable {
        case failed
        case unsupportedType
    }

    func collect<Response>(
        _ stream: AsyncThrowingStream<UploadEvent<Response>, Error>
    ) async throws -> [UploadEvent<Response>] {
        var events: [UploadEvent<Response>] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    func makeTemporaryFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetRunnerTests-\(UUID().uuidString)")
        try Data(contents.utf8).write(to: url)
        return url
    }

    func expectMultipartMetadataRejected(
        fields: [String: String],
        files: [MultipartFile],
        boundary: String
    ) async {
        let session = MockURLSession()
        session.stub(statusCode: 204)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .multipart(
                fields: fields,
                files: files,
                boundary: boundary
            )
        )

        do {
            _ = try await collect(client.upload(request: request))
            Issue.record("Expected unsafe multipart metadata to throw")
        } catch let error as NetworkError {
            guard case .requestFailed = error else {
                Issue.record("Expected NetworkError.requestFailed, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected NetworkError.requestFailed, got \(error)")
        }

        #expect(session.capturedUploadFileURLs.isEmpty)
    }

    func netRunnerTemporaryUploadFileNames() throws -> Set<String> {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let urls = try FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        )
        return Set(
            urls
                .map(\.lastPathComponent)
                .filter { $0.hasPrefix("NetRunner-") && $0.hasSuffix(".upload") }
        )
    }
}
