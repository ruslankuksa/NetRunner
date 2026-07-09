import Foundation
@testable import NetRunner

struct TestUploadRequest: UploadRequest {
    var baseURL: URL
    var method: HTTPMethod
    var endpoint: any Endpoint
    var headers: HTTPHeaders?
    var parameters: QueryParameters?
    var uploadBody: UploadBody
    var options: RequestOptions

    init(
        baseURL: URL = URL(string: "https://example.com")!,
        method: HTTPMethod = .post,
        endpoint: any Endpoint = TestEndpoint(),
        headers: HTTPHeaders? = nil,
        parameters: QueryParameters? = nil,
        uploadBody: UploadBody,
        options: RequestOptions? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.uploadBody = uploadBody
        self.options = options ?? RequestOptions(
            arrayEncoding: arrayEncoding,
            cachePolicy: cachePolicy
        )
    }
}
