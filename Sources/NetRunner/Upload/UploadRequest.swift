
import Foundation

/// Describes a file upload request: base URL, endpoint path, method, headers,
/// query parameters, an `UploadBody` source, and request options.
public protocol UploadRequest: Sendable {
    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var endpoint: any Endpoint { get }
    var headers: HTTPHeaders? { get }
    var parameters: QueryParameters? { get }
    var uploadBody: UploadBody { get }
    var options: RequestOptions { get }
}

public extension UploadRequest {
    var headers: HTTPHeaders? {
        nil
    }

    var parameters: QueryParameters? {
        nil
    }

    var options: RequestOptions {
        .default
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
            arrayEncoding: options.arrayEncoding,
            cachePolicy: options.cachePolicy
        )
    }
}
