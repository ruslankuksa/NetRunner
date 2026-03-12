
import XCTest
@testable import NetRunner

final class NetworkRequestTests: XCTestCase {

    // MARK: - URL construction

    func testMakeURLRequest_buildsCorrectURL() throws {
        let req = TestNetworkRequest(baseURL: URL(string: "https://api.example.com")!, endpoint: TestEndpoint("/users"))
        let urlReq = try req.makeURLRequest()
        XCTAssertEqual(urlReq.url?.absoluteString, "https://api.example.com/users")
    }

    func testMakeURLRequest_baseURL_validatesAtDeclarationSite() throws {
        // With baseURL as URL type, invalid URLs are caught at construction time
        // rather than at request build time — URL(string:) returns nil for invalid strings
        XCTAssertNil(URL(string: "not a valid url ://"))

        // Valid URLs with special path characters are handled by URLComponents
        let req = TestNetworkRequest(baseURL: URL(string: "https://example.com")!, endpoint: TestEndpoint("/path with spaces"))
        let urlReq = try req.makeURLRequest()
        XCTAssertNotNil(urlReq.url)
    }

    // MARK: - ArrayEncoding

    func testArrayEncoding_brackets() throws {
        let req = TestNetworkRequest(parameters: ["ids": [1, 2, 3]], arrayEncoding: .brackets)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        XCTAssertTrue(query.contains("ids=1"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=2"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=3"), "query: \(query)")
    }

    func testArrayEncoding_noBrackets() throws {
        let req = TestNetworkRequest(parameters: ["ids[]": [1, 2, 3]], arrayEncoding: .noBrackets)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        XCTAssertFalse(query.contains("[]"), "brackets should be stripped; got: \(query)")
        XCTAssertTrue(query.contains("ids=1"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=2"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=3"), "query: \(query)")
    }

    func testArrayEncoding_commaSeparated() throws {
        let req = TestNetworkRequest(parameters: ["ids": [1, 2, 3]], arrayEncoding: .commaSeparated)
        let urlReq = try req.makeURLRequest()
        let query = urlReq.url?.query ?? ""
        XCTAssertTrue(query.contains("ids=1,2,3"), "values should be comma-separated, got: \(query)")
    }

    // MARK: - GET + body throws

    func testGETWithBody_throwsHttpBodyNotAllowedForGET() {
        struct Payload: Encodable { let value = 1 }
        let req = TestNetworkRequest(method: .get, httpBody: Payload())
        XCTAssertThrowsError(try req.makeURLRequest()) { error in
            XCTAssertEqual(error as? NetworkError, .httpBodyNotAllowedForGET)
        }
    }

    // MARK: - cachePolicy propagation

    func testCachePolicy_defaultIsUseProtocolCachePolicy() throws {
        let req = TestNetworkRequest()
        let urlReq = try req.makeURLRequest()
        XCTAssertEqual(urlReq.cachePolicy, .useProtocolCachePolicy)
    }

    func testCachePolicy_returnCacheDataElseLoad_isPropagated() throws {
        let req = TestNetworkRequest(cachePolicy: .returnCacheDataElseLoad)
        let urlReq = try req.makeURLRequest()
        XCTAssertEqual(urlReq.cachePolicy, .returnCacheDataElseLoad)
    }

    func testCachePolicy_reloadIgnoringLocalCacheData_isPropagated() throws {
        let req = TestNetworkRequest(cachePolicy: .reloadIgnoringLocalCacheData)
        let urlReq = try req.makeURLRequest()
        XCTAssertEqual(urlReq.cachePolicy, .reloadIgnoringLocalCacheData)
    }
}
