
import Foundation
@testable import NetRunner

struct TestEndpoint: Endpoint {
    var path: String
    init(_ path: String = "/test") {
        self.path = path
    }
}

struct TestNetworkRequest: NetworkRequest {
    var baseURL: URL
    var method: HTTPMethod
    var endpoint: TestEndpoint
    var headers: [String: String]?
    var parameters: QueryParameters?
    var httpBody: Encodable?
    var cachePolicy: URLRequest.CachePolicy
    var arrayEncoding: ArrayEncoding

    init(
        baseURL: URL = URL(string: "https://example.com")!,
        method: HTTPMethod = .get,
        endpoint: TestEndpoint = TestEndpoint(),
        headers: [String: String]? = nil,
        parameters: QueryParameters? = nil,
        httpBody: Encodable? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.httpBody = httpBody
        self.cachePolicy = cachePolicy
        self.arrayEncoding = arrayEncoding
    }
}
