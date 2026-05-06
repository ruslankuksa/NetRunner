
import Foundation

/// Describes a file upload request.
public protocol UploadRequest: Sendable {
    associatedtype Route: Endpoint

    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var endpoint: Route { get }
    var headers: [String: String]? { get set }
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

    /// Builds a `URLRequest` from this upload request's properties.
    func makeURLRequest() throws -> URLRequest {
        let urlPath = baseURL.absoluteString + endpoint.path
        var components = URLComponents(string: urlPath)

        if let parameters = parameters, !parameters.isEmpty {
            components?.queryItems = QueryItemBuilder.buildQueryItems(from: parameters, encoding: arrayEncoding)
        }

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, method: method, headers: headers)
        request.cachePolicy = cachePolicy
        return request
    }
}

/// The body source for an upload request.
public enum UploadBody: Sendable {
    /// Uploads a file as the complete HTTP request body.
    case rawFile(fileURL: URL, contentType: String?)
    /// Uploads fields and files using `multipart/form-data`.
    case multipart(fields: [String: String], files: [MultipartFile], boundary: String?)
}

/// A file part in a multipart upload.
public struct MultipartFile: Equatable, Sendable {
    public let fieldName: String
    public let fileURL: URL
    public let fileName: String
    public let contentType: String

    public init(fieldName: String, fileURL: URL, fileName: String, contentType: String) {
        self.fieldName = fieldName
        self.fileURL = fileURL
        self.fileName = fileName
        self.contentType = contentType
    }
}

/// Progress emitted while an upload is in flight.
public struct UploadProgress: Equatable, Sendable {
    public let bytesSent: Int64
    public let totalBytesExpectedToSend: Int64
    public let attemptIndex: Int

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
    case progress(UploadProgress)
    case response(Response)
}

extension UploadEvent: Sendable where Response: Sendable {}
