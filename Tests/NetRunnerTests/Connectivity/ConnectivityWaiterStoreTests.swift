import Testing
@testable import NetRunner

@Suite(.timeLimit(.minutes(1)), .tags(.connectivity))
struct ConnectivityWaiterStoreTests {
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

        while store.pendingWaiterCount != 1 {
            await Task.yield()
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(store.pendingWaiterCount == 0)
    }
}
