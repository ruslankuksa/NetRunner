import Foundation
import Testing
@testable import NetRunner

extension NetworkClientTests {
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
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
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
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.execute(request: TestNetworkRequest(method: .post))
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
                maxRetries: 1,
                timeout: nil,
                retryableMethods: [.post]
            ),
            connectivityMonitor: connectivityMonitor
        )

        let task = Task {
            let payload: Payload = try await client.execute(
                request: TestNetworkRequest(method: .post)
            )
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
            retryPolicy: .fixed(maxRetries: 1, delay: 0),
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 0, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 2)
        #expect(await connectivityMonitor.waitCallCount == 0)
    }

    @Test func connectivityRetryBudgetExhaustionAfterWaitFallsBackToRetryPolicy() async throws {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor()
        let retryInterceptor = MockRetryInterceptor()
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0),
            retryInterceptors: [retryInterceptor],
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        let task = Task {
            try await client.execute(request: TestNetworkRequest())
        }

        await connectivityMonitor.waitForWaitCall()
        await connectivityMonitor.connect()

        await #expect(throws: NetworkError.noConnectivity) {
            try await task.value
        }
        #expect(session.callCount == 3)
        #expect(await connectivityMonitor.waitCallCount == 1)
        #expect(retryInterceptor.callCount == 2)
    }

    @Test func connectivityRetryTimeoutThrowsNoConnectivity() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor(
            waitError: NetworkError.noConnectivity
        )
        let client = makeClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: 0.01),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.execute(request: TestNetworkRequest())
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
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        let task = Task {
            try await client.execute(request: TestNetworkRequest())
        }

        await connectivityMonitor.waitForWaitCall()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(session.callCount == 1)
    }

    @Test func connectivityRetryVetoedByRetryInterceptorDoesNotWait() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let connectivityMonitor = MockConnectivityMonitor()
        let interceptor = MockRetryInterceptor(decision: .doNotRetry)
        let client = makeClient(
            session: session,
            retryInterceptors: [interceptor],
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
            connectivityMonitor: connectivityMonitor
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.execute(request: TestNetworkRequest())
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
}
