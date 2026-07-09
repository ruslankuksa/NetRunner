
import Foundation

/// Query parameters for a network request.
///
/// Values must be `Sendable` so requests can cross task boundaries
/// under Swift concurrency checking.
public typealias QueryParameters = [String: any Sendable]

/// HTTP header fields keyed by header name.
public typealias HTTPHeaders = [String: String]

/// Describes a single HTTP request: base URL, endpoint path, method, headers,
/// query parameters, and optional body.
public protocol NetworkRequest: Sendable {
    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var endpoint: any Endpoint { get }
    var headers: HTTPHeaders? { get }
    var parameters: QueryParameters? { get }
    var httpBody: (any Encodable & Sendable)? { get }

    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
    var arrayEncoding: ArrayEncoding { get }
    var cachePolicy: URLRequest.CachePolicy { get }
}

public extension NetworkRequest {

    var httpBody: (any Encodable & Sendable)? {
        nil
    }

    var decoder: JSONDecoder {
        return .init()
    }

    var encoder: JSONEncoder {
        return .init()
    }

    var arrayEncoding: ArrayEncoding {
        return .brackets
    }

    var cachePolicy: URLRequest.CachePolicy {
        return .useProtocolCachePolicy
    }

    /// Builds a `URLRequest` from this network request's properties.
    func makeURLRequest() throws -> URLRequest {
        var request = try URLRequestBuilder.makeURLRequest(
            baseURL: baseURL,
            path: endpoint.path,
            method: method,
            headers: headers,
            parameters: parameters,
            arrayEncoding: arrayEncoding,
            cachePolicy: cachePolicy
        )
        if let httpBody {
            guard method != .get else {
                throw NetworkError.httpBodyNotAllowedForGET
            }
            request.httpBody = try encoder.encode(httpBody)
        }
        return request
    }
}
