
import Foundation

/// Describes a file upload request: base URL, endpoint path, method, headers,
/// query parameters, and an `UploadBody` source.
public protocol UploadRequest: Sendable {
    associatedtype Route: Endpoint

    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var endpoint: Route { get }
    var headers: [String: String]? { get }
    var parameters: QueryParameters? { get }
    var uploadBody: UploadBody { get }

    var decoder: JSONDecoder { get }
    var arrayEncoding: ArrayEncoding { get }
    var cachePolicy: URLRequest.CachePolicy { get }
}

public extension UploadRequest {
    var decoder: JSONDecoder {
        return .init()
    }

    var arrayEncoding: ArrayEncoding {
        return .brackets
    }

    var cachePolicy: URLRequest.CachePolicy {
        return .useProtocolCachePolicy
    }

    /// Builds a `URLRequest` from this upload request's properties. Does not
    /// attach the upload body — `NetworkClient` supplies that to `URLSession`
    /// via `fromFile:`.
    func makeURLRequest() throws -> URLRequest {
        try URLRequestBuilder.makeURLRequest(
            baseURL: baseURL,
            path: endpoint.path,
            method: method,
            headers: headers,
            parameters: parameters,
            arrayEncoding: arrayEncoding,
            cachePolicy: cachePolicy
        )
    }
}

/// The body source for an upload request.
public enum UploadBody: Sendable {
    /// Uploads a file as the complete HTTP request body.
    case rawFile(fileURL: URL, contentType: String?)
    /// Uploads fields and files using `multipart/form-data`.
    case multipart(fields: [String: String], files: [MultipartFile], boundary: String?)
}

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

/// Progress emitted while an upload is in flight.
///
/// Progress reflects bytes sent on the wire for the current attempt only;
/// `attemptIndex` resets to a new attempt's counter on retry. Inter-attempt
/// ordering of progress events is best-effort because they are delivered from
/// `URLSession`'s delegate queue and may interleave with the final `.response`
/// event near completion.
public struct UploadProgress: Equatable, Sendable {
    /// Cumulative bytes sent so far for the current attempt.
    public let bytesSent: Int64
    /// Total bytes expected to be sent for the current attempt, or `-1` if unknown.
    public let totalBytesExpectedToSend: Int64
    /// Zero-based retry attempt index. Increments only when the request is retried.
    public let attemptIndex: Int

    /// Fraction in the range `0...1`, or `0` when the total size is unknown.
    public var fractionCompleted: Double {
        guard totalBytesExpectedToSend > 0 else { return 0 }
        return min(1, max(0, Double(bytesSent) / Double(totalBytesExpectedToSend)))
    }

    public init(bytesSent: Int64, totalBytesExpectedToSend: Int64, attemptIndex: Int) {
        self.bytesSent = bytesSent
        self.totalBytesExpectedToSend = totalBytesExpectedToSend
        self.attemptIndex = attemptIndex
    }
}

/// Events emitted by an upload operation.
public enum UploadEvent<Response> {
    /// Progress update for the current attempt.
    case progress(UploadProgress)
    /// The final decoded response (or `Void`) emitted once the upload succeeds.
    case response(Response)
}

extension UploadEvent: Sendable where Response: Sendable {}
