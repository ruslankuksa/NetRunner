
import Foundation

/// Query parameters for a network request.
///
/// Values must be `Sendable` so requests can cross task boundaries
/// under Swift concurrency checking.
public typealias QueryParameters = [String: QueryValue]

/// HTTP header fields keyed by header name.
public typealias HTTPHeaders = [String: String]

/// Describes a single HTTP request: base URL, endpoint path, method, headers,
/// query parameters, optional body, and request options.
public protocol NetworkRequest: Sendable {
    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var endpoint: any Endpoint { get }
    var headers: HTTPHeaders? { get }
    var parameters: QueryParameters? { get }
    var body: RequestBody? { get }
    var options: RequestOptions { get }
}

public extension NetworkRequest {

    var headers: HTTPHeaders? {
        nil
    }

    var parameters: QueryParameters? {
        nil
    }

    var body: RequestBody? {
        nil
    }

    var options: RequestOptions {
        .default
    }

    /// Builds a `URLRequest` from this network request's properties.
    func makeURLRequest() throws -> URLRequest {
        var request = try URLRequestBuilder.makeURLRequest(
            baseURL: baseURL,
            path: endpoint.path,
            method: method,
            headers: headers,
            parameters: parameters,
            arrayEncoding: options.arrayEncoding,
            cachePolicy: options.cachePolicy
        )
        if let body {
            try body.apply(
                to: &request,
                method: method,
                defaultRequestEncoder: JSONEncoder()
            )
        }
        return request
    }
}
