import Foundation
import Testing
@testable import NetRunner

extension UploadTests {
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

        let temporaryUploadFile = try #require(
            session.capturedUploadFileURLs.first
        )
        let multipartData = try #require(session.capturedUploadFileData.first)
        let multipartBody = try #require(
            String(data: multipartData, encoding: .utf8)
        )
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "Content-Type")
                == "multipart/form-data; boundary=Boundary-Test"
        )
        #expect(multipartBody.contains("--Boundary-Test\r\n"))
        #expect(
            multipartBody.contains(
                "Content-Disposition: form-data; name=\"title\"\r\n\r\nAvatar\r\n"
            )
        )
        #expect(
            multipartBody.contains(
                "Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.txt\"\r\n"
            )
        )
        #expect(
            multipartBody.contains(
                "Content-Type: text/plain\r\n\r\nfile-bytes\r\n"
            )
        )
        #expect(multipartBody.contains("--Boundary-Test--\r\n"))
        #expect(
            FileManager.default.fileExists(
                atPath: temporaryUploadFile.path
            ) == false
        )
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

    @Test func multipartPreparationFailureRemovesTemporaryFile() async throws {
        let missingFile = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "NetRunnerTests-missing-\(UUID().uuidString)"
            )
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
        } catch let error as CocoaError {
            #expect(error.code == .fileNoSuchFile)
        } catch {
            Issue.record("Expected missing-file Cocoa error, got \(error)")
        }

        #expect(session.capturedUploadFileURLs.isEmpty)
        #expect(
            try netRunnerTemporaryUploadFileNames()
                == temporaryFilesBeforeUpload
        )
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
        let multipartBody = try #require(
            String(data: multipartData, encoding: .utf8)
        )
        #expect(
            multipartBody.contains(
                "Content-Disposition: form-data; name=\"message\"\r\n\r\nfirst line\r\nsecond line\r\n"
            )
        )
    }

    @Test func multipartUploadFinalizesContentHeadersAfterRequestInterceptors() async throws {
        let session = MockURLSession()
        session.stub(statusCode: 204)
        let contentTypeInterceptor = MockRequestInterceptor()
        contentTypeInterceptor.headerToAdd = (
            name: "Content-Type",
            value: "text/plain"
        )
        let contentLengthInterceptor = MockRequestInterceptor()
        contentLengthInterceptor.headerToAdd = (
            name: "Content-Length",
            value: "0"
        )
        let client = NetworkClient(
            session: session,
            requestInterceptors: [
                contentTypeInterceptor,
                contentLengthInterceptor
            ]
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

        let capturedRequest = try #require(
            session.capturedRequests.first
        )
        let multipartData = try #require(
            session.capturedUploadFileData.first
        )
        #expect(
            capturedRequest.value(forHTTPHeaderField: "Content-Type")
                == "multipart/form-data; boundary=Boundary-Test"
        )
        #expect(
            capturedRequest.value(forHTTPHeaderField: "Content-Length")
                == String(multipartData.count)
        )
    }
}
