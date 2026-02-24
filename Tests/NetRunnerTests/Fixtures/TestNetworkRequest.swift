
import Foundation
@testable import NetRunner

struct TestEndpoint: Endpoint {
    var path: String
    init(_ path: String = "/test") {
        self.path = path
    }
}

struct TestNetworkRequest: NetworkRequest {
    var url: String
    var method: HTTPMethod
    var endpoint: Endpoint
    var headers: HTTPHeaders?
    var parameters: Parameters?
    var httpBody: Encodable?
    var cachePolicy: URLRequest.CachePolicy
    var arrayEncoding: ArrayEncoding

    init(
        url: String = "https://example.com",
        method: HTTPMethod = .get,
        endpoint: Endpoint = TestEndpoint(),
        headers: HTTPHeaders? = nil,
        parameters: Parameters? = nil,
        httpBody: Encodable? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.url = url
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.httpBody = httpBody
        self.cachePolicy = cachePolicy
        self.arrayEncoding = arrayEncoding
    }
}
