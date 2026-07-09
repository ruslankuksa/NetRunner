
import Foundation
@testable import NetRunner

struct TestNetworkRequest: NetworkRequest {
    var baseURL: URL
    var method: HTTPMethod
    var endpoint: any Endpoint
    var headers: HTTPHeaders?
    var parameters: QueryParameters?
    var cachePolicy: URLRequest.CachePolicy
    var arrayEncoding: ArrayEncoding

    init(
        baseURL: URL = URL(string: "https://example.com")!,
        method: HTTPMethod = .get,
        endpoint: any Endpoint = TestEndpoint(),
        headers: HTTPHeaders? = nil,
        parameters: QueryParameters? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.cachePolicy = cachePolicy
        self.arrayEncoding = arrayEncoding
    }
}

struct TestNetworkRequestWithBody<Body: Encodable & Sendable>: NetworkRequest {
    var baseURL: URL
    var method: HTTPMethod
    var endpoint: any Endpoint
    var headers: HTTPHeaders?
    var parameters: QueryParameters?
    var cachePolicy: URLRequest.CachePolicy
    var arrayEncoding: ArrayEncoding
    private var body: Body?

    var httpBody: (any Encodable & Sendable)? {
        body
    }

    init(
        baseURL: URL = URL(string: "https://example.com")!,
        method: HTTPMethod = .post,
        endpoint: any Endpoint = TestEndpoint(),
        headers: HTTPHeaders? = nil,
        parameters: QueryParameters? = nil,
        httpBody: Body? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.body = httpBody
        self.cachePolicy = cachePolicy
        self.arrayEncoding = arrayEncoding
    }
}
