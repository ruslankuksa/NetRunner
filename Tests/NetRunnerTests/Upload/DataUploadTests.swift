import Foundation
import Testing
@testable import NetRunner

extension UploadTests {
    @Test func dataUploadWritesBytesToTemporaryFileAndDecodesResponse() async throws {
        struct Payload: Decodable { let id: Int }

        let json = #"{"id":12}"#.data(using: .utf8)!
        let session = MockURLSession()
        session.stub(statusCode: 200)
        session.stubbedData = json
        session.uploadProgressEvents = [(5, 11), (11, 11)]
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            headers: ["X-Trace": "abc"],
            uploadBody: .data(
                data: Data("hello world".utf8),
                contentType: "text/plain"
            )
        )

        let events = try await collect(
            client.upload(request: request, responseType: Payload.self)
        )

        let temporaryUploadFile = try #require(
            session.capturedUploadFileURLs.first
        )
        let uploadedData = try #require(session.capturedUploadFileData.first)
        #expect(uploadedData == Data("hello world".utf8))
        #expect(session.capturedRequests.first?.httpMethod == "POST")
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "X-Trace") == "abc"
        )
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Content-Type") == "text/plain"
        )
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Content-Length") == "11"
        )
        #expect(
            FileManager.default.fileExists(
                atPath: temporaryUploadFile.path
            ) == false
        )

        let firstEvent = try #require(events.first)
        guard case .progress(let firstProgress) = firstEvent else {
            Issue.record("Expected first event to be upload progress")
            return
        }
        #expect(firstProgress.bytesSent == 5)
        #expect(firstProgress.totalBytesExpectedToSend == 11)
        #expect(firstProgress.fractionCompleted == 5.0 / 11.0)
        #expect(firstProgress.attemptIndex == 0)

        guard case .response(let payload) = events.last else {
            Issue.record("Expected final event to be decoded response")
            return
        }
        #expect(payload.id == 12)
    }

    @Test func dataUploadUsesClientDefaultResponseDecoder() async throws {
        struct Payload: Decodable, Sendable, Equatable {
            let value: String
        }

        struct PipeResponseBodyDecoder: ResponseBodyDecoder {
            func decode<T: Decodable>(
                _ type: T.Type,
                from data: Data
            ) throws -> T {
                guard
                    type == Payload.self,
                    let text = String(data: data, encoding: .utf8),
                    let separatorIndex = text.firstIndex(of: "|")
                else {
                    throw UploadTestCodingError.unsupportedType
                }

                let payload = Payload(
                    value: String(text[text.index(after: separatorIndex)...])
                )
                guard let typedPayload = payload as? T else {
                    throw UploadTestCodingError.unsupportedType
                }
                return typedPayload
            }
        }

        let session = MockURLSession()
        session.stub(statusCode: 200)
        session.stubbedData = Data("upload|decoded".utf8)
        let client = NetworkClient(
            session: session,
            defaultResponseDecoder: PipeResponseBodyDecoder()
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .data(
                data: Data("hello".utf8),
                contentType: "text/plain"
            )
        )

        let events = try await collect(
            client.upload(request: request, responseType: Payload.self)
        )

        guard case .response(let payload) = events.last else {
            Issue.record("Expected final event to be decoded response")
            return
        }
        #expect(payload == Payload(value: "decoded"))
    }

    @Test func dataUploadRequestResponseDecoderOverridesClientDefault() async throws {
        struct Payload: Decodable, Sendable, Equatable {
            let value: String
        }

        struct FailingResponseBodyDecoder: ResponseBodyDecoder {
            func decode<T: Decodable>(
                _ type: T.Type,
                from data: Data
            ) throws -> T {
                throw UploadTestCodingError.failed
            }
        }

        struct OverrideResponseBodyDecoder: ResponseBodyDecoder {
            func decode<T: Decodable>(
                _ type: T.Type,
                from data: Data
            ) throws -> T {
                guard
                    type == Payload.self,
                    let text = String(data: data, encoding: .utf8)
                else {
                    throw UploadTestCodingError.unsupportedType
                }

                let payload = Payload(value: text)
                guard let typedPayload = payload as? T else {
                    throw UploadTestCodingError.unsupportedType
                }
                return typedPayload
            }
        }

        let session = MockURLSession()
        session.stub(statusCode: 200)
        session.stubbedData = Data("override-decoder".utf8)
        let client = NetworkClient(
            session: session,
            defaultResponseDecoder: FailingResponseBodyDecoder()
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .data(
                data: Data("hello".utf8),
                contentType: "text/plain"
            ),
            options: RequestOptions(
                responseDecoder: OverrideResponseBodyDecoder()
            )
        )

        let events = try await collect(
            client.upload(request: request, responseType: Payload.self)
        )

        guard case .response(let payload) = events.last else {
            Issue.record("Expected final event to be decoded response")
            return
        }
        #expect(payload == Payload(value: "override-decoder"))
    }

    @Test func dataUploadDefaultsToOctetStreamContentType() async throws {
        let session = MockURLSession()
        session.stub(statusCode: 204)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .put,
            uploadBody: .data(
                data: Data("bytes".utf8),
                contentType: nil
            )
        )

        let events = try await collect(client.upload(request: request))

        #expect(session.capturedUploadFileData == [Data("bytes".utf8)])
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Content-Type")
                == "application/octet-stream"
        )
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Content-Length") == "5"
        )
        guard case .response = events.last else {
            Issue.record("Expected final event to be Void response")
            return
        }
    }

    @Test func dataUploadTemporaryFileIsRemovedAfterFailure() async throws {
        let session = MockURLSession()
        session.stub(statusCode: 503)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .data(
                data: Data("failed-bytes".utf8),
                contentType: nil
            )
        )

        await #expect(throws: NetworkError.serverError(
            response: makeTestHTTPErrorResponse(statusCode: 503)
        )) {
            _ = try await collect(client.upload(request: request))
        }

        let temporaryUploadFile = try #require(
            session.capturedUploadFileURLs.first
        )
        #expect(
            FileManager.default.fileExists(
                atPath: temporaryUploadFile.path
            ) == false
        )
    }

    @Test func dataUpload422ThrowsClientErrorContainingResponseBody() async {
        let body = Data(
            #"{"success":false,"message":["Already connected"]}"#.utf8
        )
        let session = MockURLSession()
        session.stub(statusCode: 422)
        session.stubbedData = body
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .data(
                data: Data("failed-bytes".utf8),
                contentType: nil
            )
        )

        do {
            _ = try await collect(client.upload(request: request))
            Issue.record("Expected upload to throw a 422 client error")
        } catch NetworkError.clientError(let response) {
            #expect(response.statusCode == 422)
            #expect(response.body == body)
            #expect(
                response.bodyText()
                    == #"{"success":false,"message":["Already connected"]}"#
            )
        } catch {
            Issue.record("Expected client error, got \(error)")
        }
    }
}
