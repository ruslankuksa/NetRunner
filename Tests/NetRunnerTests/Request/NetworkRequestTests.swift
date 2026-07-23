
import Testing
import Foundation
@testable import NetRunner

struct NetworkRequestTests {

    // MARK: - URL construction

    @Test func makeURLRequestBuildsCorrectURL() throws {
        let req = TestNetworkRequest(baseURL: URL(string: "https://api.example.com")!, endpoint: TestEndpoint("/users"))
        let urlReq = try req.makeURLRequest()
        #expect(urlReq.url?.absoluteString == "https://api.example.com/users")
    }

    @Test func makeURLRequestAcceptsDifferentEndpointTypes() throws {
        struct SearchEndpoint: Endpoint {
            var path: RequestPath { "/search" }
        }

        let req = TestNetworkRequest(
            baseURL: URL(string: "https://api.example.com")!,
            endpoint: SearchEndpoint()
        )

        let urlReq = try req.makeURLRequest()

        #expect(urlReq.url?.absoluteString == "https://api.example.com/search")
    }

    @Test func makeURLRequestBaseURLValidatesAtDeclarationSite() throws {
        // With baseURL as URL type, invalid URLs are caught at construction time
        // rather than at request build time — URL(string:) returns nil for invalid strings
        #expect(URL(string: "not a valid url ://") == nil)

        // Valid URLs with special path characters are handled by URLComponents
        let req = TestNetworkRequest(baseURL: URL(string: "https://example.com")!, endpoint: TestEndpoint("/path with spaces"))
        let urlReq = try req.makeURLRequest()
        #expect(urlReq.url != nil)
    }

    @Test func makeURLRequestPreservesBaseURLPathAndNormalizesSlashes() throws {
        let req = TestNetworkRequest(
            baseURL: URL(string: "https://api.example.com/v1/")!,
            endpoint: TestEndpoint("users")
        )

        let urlReq = try req.makeURLRequest()

        #expect(urlReq.url?.absoluteString == "https://api.example.com/v1/users")
    }

    @Test func makeURLRequestRejectsEndpointQueryAndFragment() {
        let queryRequest = TestNetworkRequest(endpoint: TestEndpoint("/users?name=blob"))
        let fragmentRequest = TestNetworkRequest(endpoint: TestEndpoint("/users#details"))

        #expect(throws: NetworkError.invalidURL) {
            try queryRequest.makeURLRequest()
        }
        #expect(throws: NetworkError.invalidURL) {
            try fragmentRequest.makeURLRequest()
        }
    }

    @Test func makeURLRequestRejectsEndpointSchemeAndHost() {
        let absoluteURLRequest = TestNetworkRequest(endpoint: TestEndpoint("https://evil.example/users"))

        #expect(throws: NetworkError.invalidURL) {
            try absoluteURLRequest.makeURLRequest()
        }
    }

    // MARK: - ArrayEncoding

    @Test func arrayEncodingBrackets() throws {
        let req = TestNetworkRequest(parameters: ["ids": [1, 2, 3]], arrayEncoding: .brackets)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        #expect(query.contains("ids%5B%5D=1"), "query: \(query)")
        #expect(query.contains("ids%5B%5D=2"), "query: \(query)")
        #expect(query.contains("ids%5B%5D=3"), "query: \(query)")
    }

    @Test func arrayEncodingBracketsDoesNotDoubleBracketKeys() throws {
        let req = TestNetworkRequest(parameters: ["ids[]": [1, 2]], arrayEncoding: .brackets)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        #expect(query.contains("ids%5B%5D=1"), "query: \(query)")
        #expect(query.contains("ids%5B%5D=2"), "query: \(query)")
        #expect(query.contains("ids%5B%5D%5B%5D") == false, "query: \(query)")
    }

    @Test func arrayEncodingNoBrackets() throws {
        let req = TestNetworkRequest(parameters: ["ids[]": [1, 2, 3]], arrayEncoding: .noBrackets)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        #expect(query.contains("[]") == false, "brackets should be stripped; got: \(query)")
        #expect(query.contains("ids=1"), "query: \(query)")
        #expect(query.contains("ids=2"), "query: \(query)")
        #expect(query.contains("ids=3"), "query: \(query)")
    }

    @Test func arrayEncodingCommaSeparated() throws {
        let req = TestNetworkRequest(parameters: ["ids": [1, 2, 3]], arrayEncoding: .commaSeparated)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        #expect(query.contains("ids=1,2,3"), "values should be comma-separated, got: \(query)")
    }

    @Test func queryParametersEncodeSupportedScalarValues() throws {
        let req = TestNetworkRequest(
            parameters: [
                "name": "Blob",
                "page": 2,
                "ratio": 1.5,
                "active": true,
            ]
        )

        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""

        #expect(query.contains("name=Blob"), "query: \(query)")
        #expect(query.contains("page=2"), "query: \(query)")
        #expect(query.contains("ratio=1.5"), "query: \(query)")
        #expect(query.contains("active=true"), "query: \(query)")
    }

    // MARK: - Request body

    @Test func bodylessRequestDefaultsToNoHTTPBody() throws {
        let req = TestNetworkRequest()
        let urlReq = try req.makeURLRequest()
        #expect(urlReq.httpBody == nil)
    }

    @Test func postRequestEncodesConcreteSendableBody() throws {
        struct Payload: Codable, Sendable, Equatable {
            let value: Int
        }

        let req = TestNetworkRequestWithBody(body: Payload(value: 1))
        let urlReq = try req.makeURLRequest()
        let body = try #require(urlReq.httpBody)
        let decoded = try JSONDecoder().decode(Payload.self, from: body)

        #expect(decoded == Payload(value: 1))
        #expect(urlReq.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func jsonBodyPreservesExplicitContentType() throws {
        struct Payload: Encodable, Sendable {
            let value: Int
        }

        let req = TestNetworkRequestWithBody(
            headers: ["Content-Type": "application/vnd.api+json"],
            body: Payload(value: 1)
        )

        let urlReq = try req.makeURLRequest()

        #expect(urlReq.value(forHTTPHeaderField: "Content-Type") == "application/vnd.api+json")
    }

    @Test func dataBodyWritesRawBytesAndContentType() throws {
        struct DataRequest: NetworkRequest {
            let baseURL = URL(string: "https://example.com")!
            let method: HTTPMethod = .post
            let endpoint: any Endpoint = TestEndpoint()
            let body: RequestBody? = .data(Data("raw-bytes".utf8), contentType: "text/plain")
        }

        let urlReq = try DataRequest().makeURLRequest()

        #expect(urlReq.httpBody == Data("raw-bytes".utf8))
        #expect(urlReq.value(forHTTPHeaderField: "Content-Type") == "text/plain")
    }

    @Test func dataBodyWithoutContentTypeDoesNotSetContentType() throws {
        struct DataRequest: NetworkRequest {
            let baseURL = URL(string: "https://example.com")!
            let method: HTTPMethod = .post
            let endpoint: any Endpoint = TestEndpoint()
            let body: RequestBody? = .data(Data("raw-bytes".utf8))
        }

        let urlReq = try DataRequest().makeURLRequest()

        #expect(urlReq.httpBody == Data("raw-bytes".utf8))
        #expect(urlReq.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test func getWithBodyThrowsRequestBodyNotAllowedForGET() {
        struct Payload: Encodable, Sendable { let value = 1 }
        let req = TestNetworkRequestWithBody(method: .get, body: Payload())
        #expect(throws: NetworkError.requestBodyNotAllowedForGET) {
            try req.makeURLRequest()
        }
    }

    // MARK: - cachePolicy propagation

    @Test(arguments: [
        (URLRequest.CachePolicy.useProtocolCachePolicy, URLRequest.CachePolicy.useProtocolCachePolicy),
        (URLRequest.CachePolicy.returnCacheDataElseLoad, URLRequest.CachePolicy.returnCacheDataElseLoad),
        (URLRequest.CachePolicy.reloadIgnoringLocalCacheData, URLRequest.CachePolicy.reloadIgnoringLocalCacheData),
    ])
    func cachePolicyIsPropagated(input: URLRequest.CachePolicy, expected: URLRequest.CachePolicy) throws {
        let req = TestNetworkRequest(cachePolicy: input)
        let urlReq = try req.makeURLRequest()
        #expect(urlReq.cachePolicy == expected)
    }
}
