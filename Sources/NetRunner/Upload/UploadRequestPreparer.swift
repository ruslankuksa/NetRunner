
import Foundation

internal struct PreparedUpload: Sendable {
    let request: URLRequest
    let fileURL: URL
    let temporaryFileURL: URL?
    let contentType: String
    let contentLength: String?

    func finalize(_ request: inout URLRequest) {
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let contentLength {
            request.setValue(contentLength, forHTTPHeaderField: "Content-Length")
        }
    }
}

internal enum UploadRequestPreparer {
    static func prepare(_ uploadRequest: any UploadRequest) throws -> PreparedUpload {
        guard uploadRequest.method != .get else {
            throw NetworkError.uploadBodyNotAllowedForGET
        }

        let urlRequest = try uploadRequest.makeURLRequest()
        switch uploadRequest.uploadBody {
        case .data(data: let data, contentType: let contentType):
            let temporaryFileURL = try writeUploadData(data)
            return PreparedUpload(
                request: urlRequest,
                fileURL: temporaryFileURL,
                temporaryFileURL: temporaryFileURL,
                contentType: contentType ?? "application/octet-stream",
                contentLength: contentLength(forFileAt: temporaryFileURL)
            )

        case .rawFile(let fileURL, let contentType):
            return PreparedUpload(
                request: urlRequest,
                fileURL: fileURL,
                temporaryFileURL: nil,
                contentType: contentType ?? "application/octet-stream",
                contentLength: contentLength(forFileAt: fileURL)
            )

        case .multipart(let fields, let files, let boundary):
            let boundary = boundary ?? "Boundary-\(UUID().uuidString)"
            let temporaryFileURL = try writeMultipartBody(
                fields: fields,
                files: files,
                boundary: boundary
            )
            return PreparedUpload(
                request: urlRequest,
                fileURL: temporaryFileURL,
                temporaryFileURL: temporaryFileURL,
                contentType: "multipart/form-data; boundary=\(boundary)",
                contentLength: contentLength(forFileAt: temporaryFileURL)
            )
        }
    }

    static func removeTemporaryFile(for preparedUpload: PreparedUpload) {
        if let temporaryFileURL = preparedUpload.temporaryFileURL {
            try? FileManager.default.removeItem(at: temporaryFileURL)
        }
    }

    private static func writeUploadData(_ data: Data) throws -> URL {
        let temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetRunner-\(UUID().uuidString).upload")
        do {
            try data.write(to: temporaryFileURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryFileURL)
            throw error
        }
        return temporaryFileURL
    }

    private static func writeMultipartBody(
        fields: [String: String],
        files: [MultipartFile],
        boundary: String
    ) throws -> URL {
        let temporaryFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetRunner-\(UUID().uuidString).upload")
        do {
            try MultipartFormDataBuilder.write(
                fields: fields,
                files: files,
                boundary: boundary,
                to: temporaryFileURL
            )
        } catch {
            try? FileManager.default.removeItem(at: temporaryFileURL)
            throw error
        }
        return temporaryFileURL
    }

    private static func contentLength(forFileAt fileURL: URL) -> String? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value
        else {
            return nil
        }
        return String(fileSize)
    }
}
