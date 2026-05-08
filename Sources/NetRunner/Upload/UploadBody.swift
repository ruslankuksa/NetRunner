import Foundation

/// The body source for an upload request.
public enum UploadBody: Sendable {
    /// Uploads in-memory bytes as the complete HTTP request body.
    case data(data: Data, contentType: String?)
    /// Uploads a file as the complete HTTP request body.
    case rawFile(fileURL: URL, contentType: String?)
    /// Uploads fields and files using `multipart/form-data`.
    case multipart(fields: [String: String], files: [MultipartFile], boundary: String?)
}
