import Foundation
import Testing
@testable import NetRunner

extension UploadTests {
    @Test func getUploadThrowsUploadBodyNotAllowedForGET() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        let client = NetworkClient(session: session)
        let request = TestUploadRequest(
            method: .get,
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: "text/plain"
            )
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
        interceptor.headerToAdd = (
            name: "Authorization",
            value: "Bearer token"
        )
        let client = NetworkClient(
            session: session,
            requestInterceptors: [interceptor]
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: nil
            )
        )

        _ = try await collect(client.upload(request: request))

        #expect(interceptor.interceptCallCount == 1)
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Authorization")
                == "Bearer token"
        )
    }

    @Test func retryableUploadFailureRetriesAndEmitsAttemptIndexedProgress() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stub(statusCode: 503)
        session.uploadProgressEvents = [(3, 9)]
        let client = NetworkClient(
            session: session,
            retryPolicy: .fixed(
                maxRetries: 1,
                delay: 0,
                retryableMethods: [.post]
            )
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: nil
            )
        )

        var progress: [UploadProgress] = []
        await #expect(throws: NetworkError.serverError(
            response: makeTestHTTPErrorResponse(statusCode: 503)
        )) {
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
            retryPolicy: .fixed(
                maxRetries: 1,
                delay: 0,
                retryableMethods: [.post]
            )
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: nil
            )
        )

        await #expect(throws: NetworkError.timeout) {
            _ = try await collect(client.upload(request: request))
        }

        #expect(session.capturedUploadFileURLs == [uploadFile, uploadFile])
    }

    @Test func cancelledUploadTransportFailureThrowsCancellationErrorWithoutRetry() async throws {
        let uploadFile = try makeTemporaryFile(contents: "raw-bytes")
        defer { try? FileManager.default.removeItem(at: uploadFile) }

        let session = MockURLSession()
        session.stubbedError = URLError(.cancelled)
        let client = NetworkClient(
            session: session,
            retryPolicy: .fixed(
                maxRetries: 3,
                delay: 0,
                retryableMethods: [.post]
            )
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: nil
            )
        )

        await #expect(throws: CancellationError.self) {
            _ = try await collect(client.upload(request: request))
        }

        #expect(
            session.capturedUploadFileURLs == [uploadFile],
            "Cancelled uploads should not be retried"
        )
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
            retryPolicy: .fixed(
                maxRetries: 1,
                delay: 0,
                retryableMethods: [.post]
            ),
            requestInterceptors: [requestInterceptor],
            retryInterceptors: [retryInterceptor]
        )
        let request = TestUploadRequest(
            method: .post,
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: nil
            )
        )

        await #expect(throws: NetworkError.serverError(
            response: makeTestHTTPErrorResponse(statusCode: 503)
        )) {
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
            uploadBody: .rawFile(
                fileURL: uploadFile,
                contentType: nil
            )
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
}
