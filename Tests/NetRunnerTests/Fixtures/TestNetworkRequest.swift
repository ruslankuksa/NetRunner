
import Foundation
@testable import NetRunner

struct TestNetworkRequest: NetworkRequest {
    var baseURL: URL
    var method: HTTPMethod
    var endpoint: any Endpoint
    var headers: HTTPHeaders?
    var parameters: QueryParameters?
    var options: RequestOptions

    init(
        baseURL: URL = URL(string: "https://example.com")!,
        method: HTTPMethod = .get,
        endpoint: any Endpoint = TestEndpoint(),
        headers: HTTPHeaders? = nil,
        parameters: QueryParameters? = nil,
        options: RequestOptions? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.options = options ?? RequestOptions(
            arrayEncoding: arrayEncoding,
            cachePolicy: cachePolicy
        )
    }
}

struct TestNetworkRequestWithBody<Body: Encodable & Sendable>: NetworkRequest {
    var baseURL: URL
    var method: HTTPMethod
    var endpoint: any Endpoint
    var headers: HTTPHeaders?
    var parameters: QueryParameters?
    var options: RequestOptions
    private var payload: Body?
    private var requestBodyEncoder: (any RequestBodyEncoder)?

    var body: RequestBody? {
        payload.map { .encoded($0, encoder: requestBodyEncoder) }
    }

    init(
        baseURL: URL = URL(string: "https://example.com")!,
        method: HTTPMethod = .post,
        endpoint: any Endpoint = TestEndpoint(),
        headers: HTTPHeaders? = nil,
        parameters: QueryParameters? = nil,
        body: Body? = nil,
        bodyEncoder: (any RequestBodyEncoder)? = nil,
        options: RequestOptions? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.payload = body
        self.requestBodyEncoder = bodyEncoder
        self.options = options ?? RequestOptions(
            arrayEncoding: arrayEncoding,
            cachePolicy: cachePolicy
        )
    }
}
