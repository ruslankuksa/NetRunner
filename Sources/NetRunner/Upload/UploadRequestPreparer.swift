
import Foundation

internal struct PreparedUpload {
    let request: URLRequest
    let fileURL: URL
    let temporaryFileURL: URL?
}

internal enum UploadRequestPreparer {
    static func prepare(_ uploadRequest: any UploadRequest) throws -> PreparedUpload {
        guard uploadRequest.method != .get else {
            throw NetworkError.uploadBodyNotAllowedForGET
        }

        var urlRequest = try uploadRequest.makeURLRequest()
        switch uploadRequest.uploadBody {
        case .data(data: let data, contentType: let contentType):
            let temporaryFileURL = try writeUploadData(data)
            setContentType(contentType ?? "application/octet-stream", on: &urlRequest, override: false)
            setContentLength(forFileAt: temporaryFileURL, on: &urlRequest)
            return PreparedUpload(request: urlRequest, fileURL: temporaryFileURL, temporaryFileURL: temporaryFileURL)

        case .rawFile(let fileURL, let contentType):
            setContentType(contentType ?? "application/octet-stream", on: &urlRequest, override: false)
            setContentLength(forFileAt: fileURL, on: &urlRequest)
            return PreparedUpload(request: urlRequest, fileURL: fileURL, temporaryFileURL: nil)

        case .multipart(let fields, let files, let boundary):
            let boundary = boundary ?? "Boundary-\(UUID().uuidString)"
            let temporaryFileURL = try writeMultipartBody(
                fields: fields,
                files: files,
                boundary: boundary
            )
            // NetRunner owns the multipart Content-Type because the boundary is part of correctness.
            setContentType("multipart/form-data; boundary=\(boundary)", on: &urlRequest, override: true)
            setContentLength(forFileAt: temporaryFileURL, on: &urlRequest)
            return PreparedUpload(request: urlRequest, fileURL: temporaryFileURL, temporaryFileURL: temporaryFileURL)
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

    private static func setContentType(_ contentType: String, on request: inout URLRequest, override: Bool) {
        if override || request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
    }

    private static func setContentLength(forFileAt fileURL: URL, on request: inout URLRequest) {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value
        else {
            return
        }
        request.setValue(String(fileSize), forHTTPHeaderField: "Content-Length")
    }
}
