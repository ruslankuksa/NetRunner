
import Testing
import Foundation
@testable import NetRunner

@Suite
struct NetworkClientTests {

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

    @Test func execute200DecodesResponse() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":42}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let client = makeClient(session: session)

        let result: Payload = try await client.execute(request: TestNetworkRequest())
        #expect(result.id == 42)
        #expect(session.callCount == 1)
    }

    // MARK: - Decode failure

    @Test func execute200BadJSONThrowsDecodingFailed() async {
        struct Payload: Decodable { let id: Int }
        let session = stubbedSession(statusCode: 200, data: "not json".data(using: .utf8)!)
        let client = makeClient(session: session)

        await #expect(throws: NetworkError.self) {
            let _: Payload = try await client.execute(request: TestNetworkRequest())
        }
    }

    // MARK: - HTTP error dispatch

    @Test func execute401ThrowsUnauthorized() async {
        let session = stubbedSession(statusCode: 401)
        let client = makeClient(session: session)

        await #expect(throws: NetworkError.unauthorized) {
            try await client.send(request: TestNetworkRequest())
        }
    }

    @Test func execute404ThrowsClientError() async {
        let session = stubbedSession(statusCode: 404)
        let client = makeClient(session: session)

        await #expect(throws: NetworkError.clientError(statusCode: 404)) {
            try await client.send(request: TestNetworkRequest())
        }
    }

    @Test func execute503ThrowsServerError() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(session: session)

        await #expect(throws: NetworkError.serverError(statusCode: 503)) {
            try await client.send(request: TestNetworkRequest())
        }
    }

    // MARK: - Retry — call count

    @Test func retry503ExhaustsAttempts() async {
        // maxAttempts: 3 → 1 initial + 3 retries = 4 total calls
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(session: session, retryPolicy: .exponential(maxAttempts: 3, baseDelay: 0))

        await #expect(throws: NetworkError.serverError(statusCode: 503)) {
            try await client.send(request: TestNetworkRequest())
        }
        #expect(session.callCount == 4, "1 initial + 3 retries = 4")
    }

    @Test func retry404DoesNotRetry() async {
        // 404 is a client error — isRetryable returns false
        let session = stubbedSession(statusCode: 404)
        let client = makeClient(session: session, retryPolicy: .fixed(maxAttempts: 3, delay: 0))

        await #expect(throws: NetworkError.self) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1, "Client errors should not be retried")
    }

    @Test func retryableTransportFailureRetriesRequests() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.timedOut)
        let client = makeClient(session: session, retryPolicy: .fixed(maxAttempts: 1, delay: 0))

        await #expect(throws: NetworkError.timeout) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 2, "1 initial + 1 retry = 2")
    }

    @Test func noConnectivityTransportFailureRetriesRequests() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let client = makeClient(session: session, retryPolicy: .fixed(maxAttempts: 1, delay: 0))

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 2, "1 initial + 1 retry = 2")
    }

    // MARK: - ResponseInterceptor veto

    @Test func retryVetoedByResponseInterceptorDoesNotRetry() async {
        let session = stubbedSession(statusCode: 503)
        let interceptor = MockResponseInterceptor(shouldRetryResult: false)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxAttempts: 3, delay: 0),
            responseInterceptors: [interceptor]
        )

        await #expect(throws: NetworkError.self) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1, "Interceptor vetoed — no retries")
        #expect(interceptor.callCount == 1)
    }

    @Test func requestInterceptorRunsForEachRetryAttempt() async {
        let session = stubbedSession(statusCode: 503)
        let store = RetryTokenStore(token: "initial")
        let requestInterceptor = TokenHeaderInterceptor(store: store)
        let responseInterceptor = RefreshTokenRetryInterceptor(store: store)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxAttempts: 1, delay: 0),
            requestInterceptors: [requestInterceptor],
            responseInterceptors: [responseInterceptor]
        )

        await #expect(throws: NetworkError.serverError(statusCode: 503)) {
            try await client.send(request: TestNetworkRequest())
        }

        let authorizationHeaders = session.capturedRequests.map {
            $0.value(forHTTPHeaderField: "Authorization")
        }
        #expect(requestInterceptor.interceptCallCount == 2)
        #expect(responseInterceptor.callCount == 1)
        #expect(authorizationHeaders == ["Bearer initial", "Bearer refreshed"])
    }

    // MARK: - RequestInterceptor chain order

    @Test func requestInterceptorIsAppliedBeforeRequest() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)

        let interceptor = MockRequestInterceptor()
        interceptor.headerToAdd = (name: "X-Token", value: "abc")
        let client = makeClient(session: session, requestInterceptors: [interceptor])

        let _: Payload = try await client.execute(request: TestNetworkRequest())

        #expect(interceptor.interceptCallCount == 1)
        #expect(session.capturedRequests.first?.value(forHTTPHeaderField: "X-Token") == "abc")
    }

    @Test func requestInterceptorsAppliedInOrder() async throws {
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
        #expect(captured?.value(forHTTPHeaderField: "X-First") == "1")
        #expect(captured?.value(forHTTPHeaderField: "X-Second") == "2")
    }

    // MARK: - cachePolicy forwarded

    @Test func cachePolicyForwardedToURLRequest() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let client = makeClient(session: session)

        let req = TestNetworkRequest(cachePolicy: .returnCacheDataElseLoad)
        let _: Payload = try await client.execute(request: req)

        #expect(session.capturedRequests.first?.cachePolicy == .returnCacheDataElseLoad)
    }
}
