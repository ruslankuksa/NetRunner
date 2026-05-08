import Foundation
@testable import NetRunner

// @unchecked Sendable is safe for this fixture: tests configure all stored
// values before passing the request into async upload code.
struct TestUploadRequest: UploadRequest, @unchecked Sendable {
    var baseURL: URL
    var method: HTTPMethod
    var endpoint: any Endpoint
    var headers: HTTPHeaders?
    var parameters: QueryParameters?
    var uploadBody: UploadBody
    var cachePolicy: URLRequest.CachePolicy
    var arrayEncoding: ArrayEncoding

    init(
        baseURL: URL = URL(string: "https://example.com")!,
        method: HTTPMethod = .post,
        endpoint: any Endpoint = TestEndpoint(),
        headers: HTTPHeaders? = nil,
        parameters: QueryParameters? = nil,
        uploadBody: UploadBody,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        arrayEncoding: ArrayEncoding = .brackets
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.headers = headers
        self.parameters = parameters
        self.uploadBody = uploadBody
        self.cachePolicy = cachePolicy
        self.arrayEncoding = arrayEncoding
    }
}
