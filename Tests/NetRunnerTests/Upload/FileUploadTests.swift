import Foundation
import Testing
@testable import NetRunner

extension UploadTests {
    @Test func rawFileUploadSendsFileURLAndDecodesResponse() async throws {
        struct Payload: Decodable { let id: Int }
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let json = #"{"id":7}"#.data(using: .utf8)!
        let session = MockURLSession()
        session.stub(statusCode: 200)
        session.stubbedData = json
        session.uploadProgressEvents = [(4, 9), (9, 9)]
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            headers: ["X-Trace": "abc"],
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: "text/plain"
            )
        )

        let events = try await collect(
            client.upload(request: request, responseType: Payload.self)
        )

        #expect(session.capturedUploadFileURLs == [uploadFile])
        #expect(session.capturedRequests.first?.httpMethod == "POST")
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "X-Trace") == "abc"
        )
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Content-Type") == "text/plain"
        )

        let firstEvent = try #require(events.first)
        guard case .progress(let firstProgress) = firstEvent else {
            Issue.record("Expected first event to be upload progress")
            return
        }
        #expect(firstProgress.bytesSent == 4)
        #expect(firstProgress.totalBytesExpectedToSend == 9)
        #expect(firstProgress.fractionCompleted == 4.0 / 9.0)
        #expect(firstProgress.attemptIndex == 0)

        guard case .response(let payload) = events.last else {
            Issue.record("Expected final event to be decoded response")
            return
        }
        #expect(payload.id == 7)
    }

    @Test func rawFileUploadWithoutResponseBodyCompletesWithVoid() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 204)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .put,
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: nil
            )
        )

        let events = try await collect(client.upload(request: request))

        #expect(session.capturedUploadFileURLs == [uploadFile])
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Content-Type")
                == "application/octet-stream"
        )
        guard case .response = events.last else {
            Issue.record("Expected final event to be Void response")
            return
        }
    }
}
