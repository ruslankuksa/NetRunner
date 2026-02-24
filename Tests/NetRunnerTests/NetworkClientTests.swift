
import XCTest
@testable import NetRunner

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
final class NetworkClientTests: XCTestCase {

    // MARK: - Helpers

    private func makeClient(
        session: MockURLSession,
        retryPolicy: RetryPolicy = .none,
        requestInterceptors: [any RequestInterceptor] = [],
        responseInterceptors: [any ResponseInterceptor] = []
    ) -> NetworkClient {
        NetworkClient(
            session: session,
            retryPolicy: retryPolicy,
            requestInterceptors: requestInterceptors,
            responseInterceptors: responseInterceptors
        )
    }

    private func stubbedSession(statusCode: Int, data: Data = Data()) -> MockURLSession {
        let session = MockURLSession()
        session.stub(statusCode: statusCode)
        session.stubbedData = data
        return session
    }

    // MARK: - Decode success

    func testExecute_200_decodesResponse() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":42}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let client = makeClient(session: session)

        let result: Payload = try await client.execute(request: TestNetworkRequest())
        XCTAssertEqual(result.id, 42)
        XCTAssertEqual(session.callCount, 1)
    }

    // MARK: - Decode failure

    func testExecute_200_badJSON_throwsUnableToDecode() async {
        struct Payload: Decodable { let id: Int }
        let session = stubbedSession(statusCode: 200, data: "not json".data(using: .utf8)!)
        let client = makeClient(session: session)

        do {
            let _: Payload = try await client.execute(request: TestNetworkRequest())
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            if case .unableToDecodeResponse = error { /* pass */ }
            else { XCTFail("Expected .unableToDecodeResponse, got \(error)") }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - HTTP error dispatch

    func testExecute_401_throwsNotAuthorized() async {
        let session = stubbedSession(statusCode: 401)
        let client = makeClient(session: session)

        do {
            try await client.execute(request: TestNetworkRequest())
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .notAuthorized)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testExecute_404_throwsClientError() async {
        let session = stubbedSession(statusCode: 404)
        let client = makeClient(session: session)

        do {
            try await client.execute(request: TestNetworkRequest())
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .clientError(statusCode: 404))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testExecute_503_throwsServerError() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(session: session)

        do {
            try await client.execute(request: TestNetworkRequest())
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .serverError(statusCode: 503))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Retry — call count

    func testRetry_503_exhaustsAttempts() async {
        // maxAttempts: 3 → 1 initial + 3 retries = 4 total calls
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(session: session, retryPolicy: .exponential(maxAttempts: 3, baseDelay: 0))

        do {
            try await client.execute(request: TestNetworkRequest())
            XCTFail("Expected throw")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .serverError(statusCode: 503))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        XCTAssertEqual(session.callCount, 4, "1 initial + 3 retries = 4")
    }

    func testRetry_404_doesNotRetry() async {
        // 404 is a client error — shouldRetry returns false
        let session = stubbedSession(statusCode: 404)
        let client = makeClient(session: session, retryPolicy: .fixed(maxAttempts: 3, delay: 0))

        do {
            try await client.execute(request: TestNetworkRequest())
            XCTFail("Expected throw")
        } catch { /* expected */ }

        XCTAssertEqual(session.callCount, 1, "Client errors should not be retried")
    }

    // MARK: - ResponseInterceptor veto

    func testRetry_vetoedByResponseInterceptor_doesNotRetry() async {
        let session = stubbedSession(statusCode: 503)
        let interceptor = MockResponseInterceptor(shouldRetryResult: false)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxAttempts: 3, delay: 0),
            responseInterceptors: [interceptor]
        )

        do {
            try await client.execute(request: TestNetworkRequest())
            XCTFail("Expected throw")
        } catch { /* expected */ }

        XCTAssertEqual(session.callCount, 1, "Interceptor vetoed — no retries")
        XCTAssertEqual(interceptor.callCount, 1)
    }

    // MARK: - RequestInterceptor chain order

    func testRequestInterceptor_isAppliedBeforeRequest() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)

        let interceptor = MockRequestInterceptor()
        interceptor.headerToAdd = (name: "X-Token", value: "abc")
        let client = makeClient(session: session, requestInterceptors: [interceptor])

        let _: Payload = try await client.execute(request: TestNetworkRequest())

        XCTAssertEqual(interceptor.adaptCallCount, 1)
        XCTAssertEqual(session.capturedRequests.first?.value(forHTTPHeaderField: "X-Token"), "abc")
    }

    func testRequestInterceptors_appliedInOrder() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)

        let first = MockRequestInterceptor()
        first.headerToAdd = (name: "X-First", value: "1")
        let second = MockRequestInterceptor()
        second.headerToAdd = (name: "X-Second", value: "2")

        let client = makeClient(session: session, requestInterceptors: [first, second])
        let _: Payload = try await client.execute(request: TestNetworkRequest())

        let captured = session.capturedRequests.first
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-First"), "1")
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "X-Second"), "2")
    }

    // MARK: - cachePolicy forwarded

    func testCachePolicy_forwardedToURLRequest() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let client = makeClient(session: session)

        let req = TestNetworkRequest(cachePolicy: .returnCacheDataElseLoad)
        let _: Payload = try await client.execute(request: req)

        XCTAssertEqual(session.capturedRequests.first?.cachePolicy, .returnCacheDataElseLoad)
    }
}
