
import Testing
import Foundation
@testable import NetRunner

// `multipartPreparationFailureRemovesTemporaryFile` snapshots the contents of
// `FileManager.default.temporaryDirectory` and asserts on `Set` equality, so
// running these tests in parallel with each other (or with other suites that
// touch the temp dir) would produce flakes. Hence `.serialized`.
@Suite(.serialized)
struct UploadTests {

    private enum UploadTestCodingError: Error, Sendable {
        case failed
        case unsupportedType
    }

    // MARK: - Data uploads

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
            uploadBody: .data(data: Data("hello world".utf8), contentType: "text/plain")
        )

        let events = try await collect(client.upload(request: request, responseType: Payload.self))

        let temporaryUploadFile = try #require(session.capturedUploadFileURLs.first)
        let uploadedData = try #require(session.capturedUploadFileData.first)
        #expect(uploadedData == Data("hello world".utf8))
        #expect(session.capturedRequests.first?.httpMethod == "POST")
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "X-Trace") == "abc")
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Content-Type") == "text/plain")
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Content-Length") == "11")
        #expect(!FileManager.default.fileExists(atPath: temporaryUploadFile.path))

        guard case .progress(let firstProgress) = events[0] else {
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
            func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
                guard
                    type == Payload.self,
                    let text = String(data: data, encoding: .utf8),
                    let separatorIndex = text.firstIndex(of: "|")
                else {
                    throw UploadTestCodingError.unsupportedType
                }

                let payload = Payload(value: String(text[text.index(after: separatorIndex)...]))
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
            uploadBody: .data(data: Data("hello".utf8), contentType: "text/plain")
        )

        let events = try await collect(client.upload(request: request, responseType: Payload.self))

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
            func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
                throw UploadTestCodingError.failed
            }
        }

        struct OverrideResponseBodyDecoder: ResponseBodyDecoder {
            func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
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
            uploadBody: .data(data: Data("hello".utf8), contentType: "text/plain"),
            options: RequestOptions(responseDecoder: OverrideResponseBodyDecoder())
        )

        let events = try await collect(client.upload(request: request, responseType: Payload.self))

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
            uploadBody: .data(data: Data("bytes".utf8), contentType: nil)
        )

        let events = try await collect(client.upload(request: request))

        #expect(session.capturedUploadFileData == [Data("bytes".utf8)])
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Content-Length") == "5")
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
            uploadBody: .data(data: Data("failed-bytes".utf8), contentType: nil)
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            _ = try await collect(client.upload(request: request))
        }

        let temporaryUploadFile = try #require(session.capturedUploadFileURLs.first)
        #expect(!FileManager.default.fileExists(atPath: temporaryUploadFile.path))
    }

    @Test func dataUpload422ThrowsClientErrorContainingResponseBody() async {
        let body = Data(#"{"success":false,"message":["Already connected"]}"#.utf8)
        let session = MockURLSession()
        session.stub(statusCode: 422)
        session.stubbedData = body
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .data(data: Data("failed-bytes".utf8), contentType: nil)
        )

        do {
            _ = try await collect(client.upload(request: request))
            Issue.record("Expected upload to throw a 422 client error")
        } catch NetworkError.clientError(let response) {
            #expect(response.statusCode == 422)
            #expect(response.body == body)
            #expect(response.bodyText() == #"{"success":false,"message":["Already connected"]}"#)
        } catch {
            Issue.record("Expected client error, got \(error)")
        }
    }

    // MARK: - Raw file uploads

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
            uploadBody: .rawFile(fileURL: uploadFile, contentType: "text/plain")
        )

        let events = try await collect(client.upload(request: request, responseType: Payload.self))

        #expect(session.capturedUploadFileURLs == [uploadFile])
        #expect(session.capturedRequests.first?.httpMethod == "POST")
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "X-Trace") == "abc")
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Content-Type") == "text/plain")

        guard case .progress(let firstProgress) = events[0] else {
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
            uploadBody: .rawFile(fileURL: uploadFile, contentType: nil)
        )

        let events = try await collect(client.upload(request: request))

        #expect(session.capturedUploadFileURLs == [uploadFile])
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream")
        guard case .response = events.last else {
            Issue.record("Expected final event to be Void response")
            return
        }
    }

    // MARK: - Multipart uploads

    @Test func multipartUploadWritesFieldsFilesAndBoundaryToTemporaryFile() async throws {
        let uploadFile = try makeTemporaryFile(contents: "file-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 204)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .multipart(
                fields: ["title": "Avatar"],
                files: [
                    MultipartFile(
                        fieldName: "avatar",
                        fileURL: uploadFile,
                        fileName: "avatar.txt",
                        contentType: "text/plain"
                    )
                ],
                boundary: "Boundary-Test"
            )
        )

        _ = try await collect(client.upload(request: request))

        let temporaryUploadFile = try #require(session.capturedUploadFileURLs.first)
        let multipartData = try #require(session.capturedUploadFileData.first)
        let multipartBody = try #require(String(data: multipartData, encoding: .utf8))
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=Boundary-Test")
        #expect(multipartBody.contains("--Boundary-Test\r\n"))
        #expect(multipartBody.contains("Content-Disposition: form-data; name=\"title\"\r\n\r\nAvatar\r\n"))
        #expect(multipartBody.contains("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.txt\"\r\n"))
        #expect(multipartBody.contains("Content-Type: text/plain\r\n\r\nfile-bytes\r\n"))
        #expect(multipartBody.contains("--Boundary-Test--\r\n"))
        #expect(!FileManager.default.fileExists(atPath: temporaryUploadFile.path))
    }

    @Test func multipartTemporaryFileIsRemovedAfterFailure() async throws {
        let uploadFile = try makeTemporaryFile(contents: "file-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 503)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .multipart(
                fields: [:],
                files: [
                    MultipartFile(
                        fieldName: "file",
                        fileURL: uploadFile,
                        fileName: "file.txt",
                        contentType: "text/plain"
                    )
                ],
                boundary: "Boundary-Failure"
            )
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            _ = try await collect(client.upload(request: request))
        }

        let temporaryUploadFile = try #require(session.capturedUploadFileURLs.first)
        #expect(!FileManager.default.fileExists(atPath: temporaryUploadFile.path))
    }

    @Test func multipartPreparationFailureRemovesTemporaryFile() async throws {
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetRunnerTests-missing-\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: missingFile)
        let temporaryFilesBeforeUpload = try netRunnerTemporaryUploadFileNames()

        let session = MockURLSession()
        session.stub(statusCode: 204)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .multipart(
                fields: [:],
                files: [
                    MultipartFile(
                        fieldName: "file",
                        fileURL: missingFile,
                        fileName: "missing.txt",
                        contentType: "text/plain"
                    )
                ],
                boundary: "Boundary-Missing"
            )
        )

        do {
            _ = try await collect(client.upload(request: request))
            Issue.record("Expected multipart preparation to throw")
        } catch {}

        #expect(session.capturedUploadFileURLs.isEmpty)
        #expect(try netRunnerTemporaryUploadFileNames() == temporaryFilesBeforeUpload)
    }

    @Test func multipartUploadRejectsUnsafeFieldName() async throws {
        await expectMultipartMetadataRejected(
            fields: ["title\r\nX-Injected: true": "Avatar"],
            files: [],
            boundary: "Boundary-Test"
        )
    }

    @Test func multipartUploadRejectsUnsafeFileFieldName() async throws {
        let uploadFile = try makeTemporaryFile(contents: "file-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        await expectMultipartMetadataRejected(
            fields: [:],
            files: [
                MultipartFile(
                    fieldName: "file\r\nX-Injected: true",
                    fileURL: uploadFile,
                    fileName: "file.txt",
                    contentType: "text/plain"
                )
            ],
            boundary: "Boundary-Test"
        )
    }

    @Test func multipartUploadRejectsUnsafeFileName() async throws {
        let uploadFile = try makeTemporaryFile(contents: "file-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        await expectMultipartMetadataRejected(
            fields: [:],
            files: [
                MultipartFile(
                    fieldName: "file",
                    fileURL: uploadFile,
                    fileName: "file.txt\r\nX-Injected: true",
                    contentType: "text/plain"
                )
            ],
            boundary: "Boundary-Test"
        )
    }

    @Test func multipartUploadRejectsUnsafeContentType() async throws {
        let uploadFile = try makeTemporaryFile(contents: "file-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        await expectMultipartMetadataRejected(
            fields: [:],
            files: [
                MultipartFile(
                    fieldName: "file",
                    fileURL: uploadFile,
                    fileName: "file.txt",
                    contentType: "text/plain\r\nX-Injected: true"
                )
            ],
            boundary: "Boundary-Test"
        )
    }

    @Test func multipartUploadRejectsUnsafeBoundary() async throws {
        await expectMultipartMetadataRejected(
            fields: ["title": "Avatar"],
            files: [],
            boundary: "Boundary-Test\r\nX-Injected: true"
        )
    }

    @Test func multipartFieldValuesMayContainLineBreaks() async throws {
        let session = MockURLSession()
        session.stub(statusCode: 204)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .multipart(
                fields: ["message": "first line\r\nsecond line"],
                files: [],
                boundary: "Boundary-Value"
            )
        )

        _ = try await collect(client.upload(request: request))

        let multipartData = try #require(session.capturedUploadFileData.first)
        let multipartBody = try #require(String(data: multipartData, encoding: .utf8))
        #expect(multipartBody.contains("Content-Disposition: form-data; name=\"message\"\r\n\r\nfirst line\r\nsecond line\r\n"))
    }

    @Test func multipartUploadFinalizesContentHeadersAfterRequestInterceptors() async throws {
        let session = MockURLSession()
        session.stub(statusCode: 204)
        let contentTypeInterceptor = MockRequestInterceptor()
        contentTypeInterceptor.headerToAdd = (name: "Content-Type", value: "text/plain")
        let contentLengthInterceptor = MockRequestInterceptor()
        contentLengthInterceptor.headerToAdd = (name: "Content-Length", value: "0")
        let client = NetworkClient(
            session: session,
            requestInterceptors: [contentTypeInterceptor, contentLengthInterceptor]
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .multipart(
                fields: ["title": "Avatar"],
                files: [],
                boundary: "Boundary-Test"
            )
        )

        _ = try await collect(client.upload(request: request))

        let capturedRequest = try #require(session.capturedRequests.first)
        let multipartData = try #require(session.capturedUploadFileData.first)
        #expect(capturedRequest.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=Boundary-Test")
        #expect(capturedRequest.value(forHTTPHeaderField: "Content-Length") == String(multipartData.count))
    }

    // MARK: - Validation, interceptors, and retry

    @Test func getUploadThrowsUploadBodyNotAllowedForGET() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .get,
            uploadBody: .rawFile(fileURL: uploadFile, contentType: "text/plain")
        )

        await #expect(throws: NetworkError.uploadBodyNotAllowedForGET) {
            _ = try await collect(client.upload(request: request))
        }
        #expect(session.capturedRequests.isEmpty)
        #expect(session.capturedUploadFileURLs.isEmpty)
    }

    @Test func requestInterceptorRunsBeforeUploadStarts() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 204)
        let interceptor = MockRequestInterceptor()
        interceptor.headerToAdd = (name: "Authorization", value: "Bearer token")
        let client = NetworkClient(session: session, requestInterceptors: [interceptor])
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(fileURL: uploadFile, contentType: nil)
        )

        _ = try await collect(client.upload(request: request))

        #expect(interceptor.interceptCallCount == 1)
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test func retryableUploadFailureRetriesAndEmitsAttemptIndexedProgress() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 503)
        session.uploadProgressEvents = [(3, 9)]
        let client = NetworkClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0, retryableMethods: [.post])
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(fileURL: uploadFile, contentType: nil)
        )

        var progress: [UploadProgress] = []
        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            for try await event in client.upload(request: request) {
                if case .progress(let uploadProgress) = event {
                    progress.append(uploadProgress)
                }
            }
        }

        #expect(session.capturedUploadFileURLs == [uploadFile, uploadFile])
        #expect(progress.map(\.attemptIndex) == [0, 1])
    }

    @Test func retryableUploadTransportFailureRetries() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stubbedError = URLError(.timedOut)
        let client = NetworkClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0, retryableMethods: [.post])
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(fileURL: uploadFile, contentType: nil)
        )

        await #expect(throws: NetworkError.timeout) {
            _ = try await collect(client.upload(request: request))
        }

        #expect(session.capturedUploadFileURLs == [uploadFile, uploadFile])
    }

    @Test func requestInterceptorRunsForEachUploadRetryAttempt() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 503)
        let store = RetryTokenStore(token: "initial")
        let requestInterceptor = TokenHeaderInterceptor(store: store)
        let retryInterceptor = RefreshTokenRetryInterceptor(store: store)
        let client = NetworkClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0, retryableMethods: [.post]),
            requestInterceptors: [requestInterceptor],
            retryInterceptors: [retryInterceptor]
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(fileURL: uploadFile, contentType: nil)
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            _ = try await collect(client.upload(request: request))
        }

        let authorizationHeaders = session.capturedRequests.map {
            $0.value(forHTTPHeaderField: "Authorization")
        }
        #expect(requestInterceptor.interceptCallCount == 2)
        #expect(retryInterceptor.callCount == 1)
        #expect(authorizationHeaders == ["Bearer initial", "Bearer refreshed"])
    }

    @Test func connectivityRetryWaitsUntilConnectedBeforeRetryingUpload() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 204)
        session.uploadProgressEvents = [(3, 9)]
        session.uploadResults = [
            .failure(URLError(.notConnectedToInternet)),
            .success((Data(), session.stubbedResponse))
        ]
        let connectivityMonitor = MockConnectivityMonitor()
        let client = NetworkClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(
                maxRetries: 1,
                timeout: nil,
                retryableMethods: [.post]
            ),
            connectivityMonitor: connectivityMonitor
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(fileURL: uploadFile, contentType: nil)
        )

        let task = Task { () throws -> [UploadProgress] in
            var progress: [UploadProgress] = []
            for try await event in client.upload(request: request) {
                if case .progress(let uploadProgress) = event {
                    progress.append(uploadProgress)
                }
            }
            return progress
        }

        await connectivityMonitor.waitForWaitCall()
        #expect(session.capturedUploadFileURLs == [uploadFile])

        await connectivityMonitor.connect()
        let progress = try await task.value

        #expect(session.capturedUploadFileURLs == [uploadFile, uploadFile])
        #expect(progress.map(\.attemptIndex) == [0, 1])
        #expect(await connectivityMonitor.waitCallCount == 1)
    }

    // MARK: - Helpers

    private func collect<Response>(
        _ stream: AsyncThrowingStream<UploadEvent<Response>, Error>
    ) async throws -> [UploadEvent<Response>] {
        var events: [UploadEvent<Response>] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    private func makeTemporaryFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetRunnerTests-\(UUID().uuidString)")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func expectMultipartMetadataRejected(
        fields: [String: String],
        files: [MultipartFile],
        boundary: String
    ) async {
        let session = MockURLSession()
        session.stub(statusCode: 204)
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .multipart(fields: fields, files: files, boundary: boundary)
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

    private func netRunnerTemporaryUploadFileNames() throws -> Set<String> {
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
