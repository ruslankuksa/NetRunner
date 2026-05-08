import Foundation

/// A file part in a `multipart/form-data` upload.
public struct MultipartFile: Equatable, Sendable {
    /// The multipart field name this file is attached to.
    public let fieldName: String
    /// The local file URL whose contents are uploaded.
    public let fileURL: URL
    /// The filename advertised in the `Content-Disposition` header.
    public let fileName: String
    /// The MIME type advertised in the part's `Content-Type` header.
    public let contentType: String

    public init(fieldName: String, fileURL: URL, fileName: String, contentType: String) {
        self.fieldName = fieldName
        self.fileURL = fileURL
        self.fileName = fileName
        self.contentType = contentType
    }
}
