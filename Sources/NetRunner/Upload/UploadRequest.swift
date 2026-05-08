
import Foundation

/// Describes a file upload request: base URL, endpoint path, method, headers,
/// query parameters, and an `UploadBody` source.
public protocol UploadRequest: Sendable {
    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var endpoint: any Endpoint { get }
    var headers: HTTPHeaders? { get }
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
