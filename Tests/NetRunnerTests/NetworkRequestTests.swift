
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

    @Test func makeURLRequestBaseURLValidatesAtDeclarationSite() throws {
        // With baseURL as URL type, invalid URLs are caught at construction time
        // rather than at request build time — URL(string:) returns nil for invalid strings
        #expect(URL(string: "not a valid url ://") == nil)

        // Valid URLs with special path characters are handled by URLComponents
        let req = TestNetworkRequest(baseURL: URL(string: "https://example.com")!, endpoint: TestEndpoint("/path with spaces"))
        let urlReq = try req.makeURLRequest()
        #expect(urlReq.url != nil)
    }

    // MARK: - ArrayEncoding

    @Test func arrayEncodingBrackets() throws {
        let req = TestNetworkRequest(parameters: ["ids": [1, 2, 3]], arrayEncoding: .brackets)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        #expect(query.contains("ids=1"), "query: \(query)")
        #expect(query.contains("ids=2"), "query: \(query)")
        #expect(query.contains("ids=3"), "query: \(query)")
    }

    @Test func arrayEncodingNoBrackets() throws {
        let req = TestNetworkRequest(parameters: ["ids[]": [1, 2, 3]], arrayEncoding: .noBrackets)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        #expect(!query.contains("[]"), "brackets should be stripped; got: \(query)")
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

    // MARK: - GET + body throws

    @Test func getWithBodyThrowsHttpBodyNotAllowedForGET() {
        struct Payload: Encodable { let value = 1 }
        let req = TestNetworkRequest(method: .get, httpBody: Payload())
        #expect(throws: NetworkError.httpBodyNotAllowedForGET) {
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
