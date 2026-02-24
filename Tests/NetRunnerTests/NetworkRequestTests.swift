
import XCTest
@testable import NetRunner

final class NetworkRequestTests: XCTestCase {

    // MARK: - URL construction

    func testAsURLRequest_buildsCorrectURL() throws {
        let req = TestNetworkRequest(url: "https://api.example.com", endpoint: TestEndpoint("/users"))
        let urlReq = try req.asURLRequest()
        XCTAssertEqual(urlReq.url?.absoluteString, "https://api.example.com/users")
    }

    func testAsURLRequest_badURL_throws() {
        let req = TestNetworkRequest(url: "not a valid url ://", endpoint: TestEndpoint(""))
        XCTAssertThrowsError(try req.asURLRequest()) { error in
            XCTAssertEqual(error as? NetworkError, .badURL)
        }
    }

    // MARK: - ArrayEncoding

    func testArrayEncoding_brackets() throws {
        let req = TestNetworkRequest(parameters: ["ids": [1, 2, 3]], arrayEncoding: .brackets)
        let urlReq = try req.asURLRequest()
        let query = urlReq.url?.query ?? ""
        XCTAssertTrue(query.contains("ids=1"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=2"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=3"), "query: \(query)")
    }

    func testArrayEncoding_noBrackets() throws {
        let req = TestNetworkRequest(parameters: ["ids[]": [1, 2, 3]], arrayEncoding: .noBrackets)
        let urlReq = try req.asURLRequest()
        let query = urlReq.url?.query ?? ""
        XCTAssertFalse(query.contains("[]"), "brackets should be stripped; got: \(query)")
        XCTAssertTrue(query.contains("ids=1"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=2"), "query: \(query)")
        XCTAssertTrue(query.contains("ids=3"), "query: \(query)")
    }

    func testArrayEncoding_commaSeparated() throws {
        let req = TestNetworkRequest(parameters: ["ids": [1, 2, 3]], arrayEncoding: .commaSeparated)
        let urlReq = try req.asURLRequest()
        let query = urlReq.url?.query ?? ""
        XCTAssertTrue(query.contains("ids=1,2,3"), "values should be comma-separated, got: \(query)")
    }

    // MARK: - GET + body throws

    func testGETWithBody_throwsNotAllowedRequest() {
        struct Payload: Encodable { let value = 1 }
        let req = TestNetworkRequest(method: .get, httpBody: Payload())
        XCTAssertThrowsError(try req.asURLRequest()) { error in
            XCTAssertEqual(error as? NetworkError, .notAllowedRequest)
        }
    }

    // MARK: - cachePolicy propagation

    func testCachePolicy_defaultIsUseProtocolCachePolicy() throws {
        let req = TestNetworkRequest()
        let urlReq = try req.asURLRequest()
        XCTAssertEqual(urlReq.cachePolicy, .useProtocolCachePolicy)
    }

    func testCachePolicy_returnCacheDataElseLoad_isPropagated() throws {
        let req = TestNetworkRequest(cachePolicy: .returnCacheDataElseLoad)
        let urlReq = try req.asURLRequest()
        XCTAssertEqual(urlReq.cachePolicy, .returnCacheDataElseLoad)
    }

    func testCachePolicy_reloadIgnoringLocalCacheData_isPropagated() throws {
        let req = TestNetworkRequest(cachePolicy: .reloadIgnoringLocalCacheData)
        let urlReq = try req.asURLRequest()
        XCTAssertEqual(urlReq.cachePolicy, .reloadIgnoringLocalCacheData)
    }
}
