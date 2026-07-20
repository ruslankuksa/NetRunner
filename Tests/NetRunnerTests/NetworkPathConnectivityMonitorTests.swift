import Testing
@testable import NetRunner

@Suite struct NetworkPathConnectivityMonitorTests {
    @Test func pathHandlerPublishesNothingBeforeEvaluatedCallback() async {
        let source = ControllableNetworkPathUpdateSource()
        let monitor = PathUpdateHandlerConnectivityMonitor(source: source)
        var stateIterator = monitor.connectivityStates().makeAsyncIterator()
        var updateIterator = monitor.connectivityStateUpdates().makeAsyncIterator()

        #expect(await monitor.currentConnectivityState == nil)

        monitor.cancel()

        #expect(await stateIterator.next() == nil)
        #expect(await updateIterator.next() == nil)
    }

    @Test func pathHandlerRegistersUpdateStreamBeforeStartingSource() async {
        let source = ControllableNetworkPathUpdateSource(
            updatesOnStart: [.disconnected, .connected]
        )
        let monitor = PathUpdateHandlerConnectivityMonitor(source: source)
        var iterator = monitor.connectivityStateUpdates().makeAsyncIterator()

        #expect(
            await iterator.next()
                == ConnectivityStateUpdate(sequence: 1, state: .disconnected)
        )
        #expect(
            await iterator.next()
                == ConnectivityStateUpdate(sequence: 2, state: .connected)
        )

        monitor.cancel()
    }

    @Test func pathHandlerRegistersRestorationWaiterBeforeStartingSource() async throws {
        let source = ControllableNetworkPathUpdateSource(updatesOnStart: [.connected])
        let monitor = PathUpdateHandlerConnectivityMonitor(source: source)

        try await monitor.waitForConnectivityRestoration(timeout: nil)

        #expect(await monitor.currentConnectivityState == .connected)
        monitor.cancel()
    }

    @Test func pathHandlerCancellationFinishesBothStreams() async {
        let source = ControllableNetworkPathUpdateSource()
        let monitor = PathUpdateHandlerConnectivityMonitor(source: source)
        var stateIterator = monitor.connectivityStates().makeAsyncIterator()
        var updateIterator = monitor.connectivityStateUpdates().makeAsyncIterator()

        monitor.cancel()

        #expect(await stateIterator.next() == nil)
        #expect(await updateIterator.next() == nil)
        #expect(source.isCancelled)
    }

    @Test func networkPathMonitorForwardsOrderedUpdates() async {
        let source = ControllableNetworkPathUpdateSource(updatesOnStart: [.connected])
        let implementation = PathUpdateHandlerConnectivityMonitor(source: source)
        let monitor = NetworkPathConnectivityMonitor(implementation: implementation)
        let provider: any ConnectivityStateUpdateProviding = monitor
        var iterator = provider.connectivityStateUpdates().makeAsyncIterator()

        #expect(
            await iterator.next()
                == ConnectivityStateUpdate(sequence: 1, state: .connected)
        )

        monitor.cancel()
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @Test func asyncSequencePublishesNothingBeforeEvaluatedCallback() async {
        let source = ControllableNetworkPathUpdateSource()
        let monitor = AsyncSequenceNetworkPathConnectivityMonitor(source: source)
        var stateIterator = monitor.connectivityStates().makeAsyncIterator()
        var updateIterator = monitor.connectivityStateUpdates().makeAsyncIterator()

        #expect(await monitor.currentConnectivityState == nil)

        monitor.cancel()

        #expect(await stateIterator.next() == nil)
        #expect(await updateIterator.next() == nil)
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @Test func asyncSequenceRegistersUpdateStreamBeforeStartingSource() async {
        let source = ControllableNetworkPathUpdateSource(
            updatesOnStart: [.disconnected, .connected]
        )
        let monitor = AsyncSequenceNetworkPathConnectivityMonitor(source: source)
        var iterator = monitor.connectivityStateUpdates().makeAsyncIterator()

        #expect(
            await iterator.next()
                == ConnectivityStateUpdate(sequence: 1, state: .disconnected)
        )
        #expect(
            await iterator.next()
                == ConnectivityStateUpdate(sequence: 2, state: .connected)
        )

        monitor.cancel()
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @Test func asyncSequenceRegistersRestorationWaiterBeforeStartingSource() async throws {
        let source = ControllableNetworkPathUpdateSource(updatesOnStart: [.connected])
        let monitor = AsyncSequenceNetworkPathConnectivityMonitor(source: source)

        try await monitor.waitForConnectivityRestoration(timeout: nil)

        #expect(await monitor.currentConnectivityState == .connected)
        monitor.cancel()
    }

    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    @Test func asyncSequenceCancellationFinishesBothStreams() async {
        let source = ControllableNetworkPathUpdateSource()
        let monitor = AsyncSequenceNetworkPathConnectivityMonitor(source: source)
        var stateIterator = monitor.connectivityStates().makeAsyncIterator()
        var updateIterator = monitor.connectivityStateUpdates().makeAsyncIterator()

        monitor.cancel()

        #expect(await stateIterator.next() == nil)
        #expect(await updateIterator.next() == nil)
        #expect(source.isCancelled)
    }
}
