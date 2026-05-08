
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
        responseInterceptors: [any ResponseInterceptor] = [],
        connectivityRetryPolicy: ConnectivityRetryPolicy = .disabled,
        connectivityMonitor: (any ConnectivityMonitor)? = MockConnectivityMonitor()
    ) -> NetworkClient {
        NetworkClient(
            session: session,
            retryPolicy: retryPolicy,
            requestInterceptors: requestInterceptors,
            responseInterceptors: responseInterceptors,
            connectivityRetryPolicy: connectivityRetryPolicy,
            connectivityMonitor: connectivityMonitor
        )
    }

    private func stubbedSession(statusCode: Int, data: Data = Data()) -> MockURLSession {
        let session = MockURLSession()
        session.stub(statusCode: statusCode)
        session.stubbedData = data
        return session
    }

    private enum ConnectivityStateTestError: Error {
        case timedOut
        case finishedWithoutValue
    }

    private func firstConnectivityState(
        from stream: AsyncStream<ConnectivityState>,
        timeout: TimeInterval = 2
    ) async throws -> ConnectivityState {
        try await withThrowingTaskGroup(of: ConnectivityState.self) { group in
            group.addTask {
                for await state in stream.prefix(1) {
                    return state
                }
                throw ConnectivityStateTestError.finishedWithoutValue
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ConnectivityStateTestError.timedOut
            }

            guard let state = try await group.next() else {
                throw ConnectivityStateTestError.finishedWithoutValue
            }
            group.cancelAll()
            return state
        }
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

    @Test func retryPolicyDoesNotRetryPostByDefault() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(session: session, retryPolicy: .fixed(maxAttempts: 1, delay: 0))

        await #expect(throws: NetworkError.serverError(statusCode: 503)) {
            try await client.send(request: TestNetworkRequest(method: .post))
        }

        #expect(session.callCount == 1)
    }

    @Test func retryPolicyRetriesPostWhenAllowed() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxAttempts: 1, delay: 0, retryableMethods: [.post])
        )

        await #expect(throws: NetworkError.serverError(statusCode: 503)) {
            try await client.send(request: TestNetworkRequest(method: .post))
        }

        #expect(session.callCount == 2)
    }

    @Test func retryPolicyDoesNotRetryUnknownHTTPMethod() async {
        let session = stubbedSession(statusCode: 503)
        let interceptor = MockRequestInterceptor()
        interceptor.methodOverride = "CUSTOM"
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxAttempts: 1, delay: 0),
            requestInterceptors: [interceptor]
        )

        await #expect(throws: NetworkError.serverError(statusCode: 503)) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1)
    }

    @Test func disabledConnectivityRetryDoesNotCreateDefaultMonitor() {
        let session = MockURLSession()
        var factoryCallCount = 0

        _ = NetworkClient(
            session: session,
            connectivityRetryPolicy: .disabled,
            connectivityMonitorFactory: {
                factoryCallCount += 1
                return TestCancellableConnectivityMonitor()
            }
        )

        #expect(factoryCallCount == 0)
    }

    @Test func enabledConnectivityRetryCreatesDefaultMonitorWhenNotInjected() {
        let session = MockURLSession()
        var factoryCallCount = 0

        _ = NetworkClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitorFactory: {
                factoryCallCount += 1
                return TestCancellableConnectivityMonitor()
            }
        )

        #expect(factoryCallCount == 1)
    }

    @Test func ownedConnectivityMonitorIsCancelledOnDeinit() {
        let session = MockURLSession()
        let monitor = TestCancellableConnectivityMonitor()
        var client: NetworkClient? = NetworkClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitorFactory: { monitor }
        )

        #expect(client != nil)
        client = nil

        #expect(monitor.cancelCallCount == 1)
    }

    @Test func injectedConnectivityMonitorIsNotCancelledOnDeinit() {
        let session = MockURLSession()
        let monitor = TestCancellableConnectivityMonitor()
        var client: NetworkClient? = NetworkClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitor: monitor,
            connectivityMonitorFactory: {
                Issue.record("Injected monitor should avoid default factory")
                return TestCancellableConnectivityMonitor()
            }
        )

        #expect(client != nil)
        client = nil

        #expect(monitor.cancelCallCount == 0)
    }

    @Test func connectivityRetryWaitsUntilConnectedBeforeRetryingRequest() async throws {
        struct Payload: Decodable { let id: Int }

        let json = #"{"id":7}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        session.dataResults = [
            .failure(URLError(.notConnectedToInternet)),
            .success((json, session.stubbedResponse))
        ]
        let connectivityMonitor = MockConnectivityMonitor()
        let client = makeClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        let task = Task {
            let payload: Payload = try await client.execute(request: TestNetworkRequest())
            return payload
        }

        await connectivityMonitor.waitForWaitCall()
        #expect(session.callCount == 1)

        await connectivityMonitor.connect()
        let payload = try await task.value

        #expect(payload.id == 7)
        #expect(session.callCount == 2)
        #expect(await connectivityMonitor.waitCallCount == 1)
        #expect(await connectivityMonitor.capturedTimeouts == [nil])
    }

    @Test func connectivityRetryDoesNotWaitForPostByDefault() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor()
        let client = makeClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.send(request: TestNetworkRequest(method: .post))
        }

        #expect(session.callCount == 1)
        #expect(await connectivityMonitor.waitCallCount == 0)
    }

    @Test func connectivityRetryWaitsForPostWhenAllowed() async throws {
        struct Payload: Decodable { let id: Int }

        let json = #"{"id":7}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        session.dataResults = [
            .failure(URLError(.notConnectedToInternet)),
            .success((json, session.stubbedResponse))
        ]
        let connectivityMonitor = MockConnectivityMonitor()
        let client = makeClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(
                maxAttempts: 1,
                timeout: nil,
                retryableMethods: [.post]
            ),
            connectivityMonitor: connectivityMonitor
        )

        let task = Task {
            let payload: Payload = try await client.execute(request: TestNetworkRequest(method: .post))
            return payload
        }

        await connectivityMonitor.waitForWaitCall()
        #expect(session.callCount == 1)

        await connectivityMonitor.connect()
        let payload = try await task.value

        #expect(payload.id == 7)
        #expect(session.callCount == 2)
        #expect(await connectivityMonitor.waitCallCount == 1)
    }

    @Test func exhaustedConnectivityRetryFallsBackToRetryPolicy() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor()
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxAttempts: 1, delay: 0),
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 0, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 2)
        #expect(await connectivityMonitor.waitCallCount == 0)
    }

    @Test func connectivityRetryBudgetExhaustionAfterWaitFallsBackToRetryPolicy() async throws {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor()
        let responseInterceptor = MockResponseInterceptor()
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxAttempts: 1, delay: 0),
            responseInterceptors: [responseInterceptor],
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        let task = Task {
            try await client.send(request: TestNetworkRequest())
        }

        await connectivityMonitor.waitForWaitCall()
        await connectivityMonitor.connect()

        await #expect(throws: NetworkError.noConnectivity) {
            try await task.value
        }
        #expect(session.callCount == 3)
        #expect(await connectivityMonitor.waitCallCount == 1)
        #expect(responseInterceptor.callCount == 2)
    }

    @Test func connectivityRetryTimeoutThrowsNoConnectivity() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor(waitError: NetworkError.noConnectivity)
        let client = makeClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: 0.01),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1)
        #expect(await connectivityMonitor.waitCallCount == 1)
        #expect(await connectivityMonitor.capturedTimeouts == [0.01])
    }

    @Test func connectivityRetryCancellationThrowsCancellationError() async throws {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor()
        let client = makeClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        let task = Task {
            try await client.send(request: TestNetworkRequest())
        }

        await connectivityMonitor.waitForWaitCall()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(session.callCount == 1)
    }

    @Test func connectivityRetryVetoedByResponseInterceptorDoesNotWait() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor()
        let interceptor = MockResponseInterceptor(shouldRetryResult: false)
        let client = makeClient(
            session: session,
            responseInterceptors: [interceptor],
            connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.send(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1)
        #expect(interceptor.callCount == 1)
        #expect(await connectivityMonitor.waitCallCount == 0)
    }

    @Test func connectivityStateStreamYieldsCurrentStateToNewSubscriber() async {
        let store = ConnectivityStateStore()
        store.update(.connected)

        var states: [ConnectivityState] = []
        for await state in store.stream().prefix(1) {
            states.append(state)
        }

        #expect(states == [.connected])
    }

    @Test func connectivityStateStoreCurrentStateReturnsLatestKnownState() {
        let store = ConnectivityStateStore()
        #expect(store.currentState == nil)

        store.update(.connected)
        #expect(store.currentState == .connected)
    }

    @Test func connectivityStateStreamBroadcastsStateChanges() async {
        let store = ConnectivityStateStore()
        var first = store.stream().makeAsyncIterator()
        var second = store.stream().makeAsyncIterator()

        store.update(.disconnected)

        let firstState = await first.next()
        let secondState = await second.next()

        #expect(firstState == .disconnected)
        #expect(secondState == .disconnected)
    }

    @Test func connectivityStateStreamSuppressesDuplicateStates() async throws {
        let store = ConnectivityStateStore()
        var iterator = store.stream().makeAsyncIterator()

        store.update(.connected)
        let firstState = await iterator.next()
        store.update(.connected)
        store.update(.disconnected)
        let secondState = await iterator.next()

        #expect(firstState == .connected)
        #expect(secondState == .disconnected)
    }

    @Test func networkPathConnectivityMonitorProvidesConnectivityStates() async throws {
        let monitor = NetworkPathConnectivityMonitor()
        defer { monitor.cancel() }
        let provider: any ConnectivityStateProviding = monitor

        let state = try await firstConnectivityState(from: provider.connectivityStates())

        #expect(state == .connected || state == .disconnected)
    }

    @Test func mockConnectivityMonitorPublishesConnectivityState() async {
        let monitor = MockConnectivityMonitor()
        var iterator = monitor.connectivityStates().makeAsyncIterator()

        await monitor.updateConnectivityState(.disconnected)
        let state = await iterator.next()

        #expect(state == .disconnected)
    }

    @Test func mockConnectivityMonitorExposesCurrentConnectivityState() async {
        let monitor = MockConnectivityMonitor()
        #expect(monitor.currentConnectivityState == nil)

        await monitor.updateConnectivityState(.connected)

        #expect(monitor.currentConnectivityState == .connected)
    }

    @Test func connectivityRestorationWaitRequiresFutureConnectedUpdate() async {
        let store = ConnectivityWaiterStore()
        store.updateConnectivity(true)

        await #expect(throws: NetworkError.noConnectivity) {
            try await store.waitForConnectivityRestoration(timeout: 0)
        }
    }

    @Test func connectivityWaitWithTimeoutCancellationThrowsCancellationError() async {
        let store = ConnectivityWaiterStore()

        let task = Task {
            try await store.waitUntilConnected(timeout: 60)
        }
        await Task.yield()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
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
