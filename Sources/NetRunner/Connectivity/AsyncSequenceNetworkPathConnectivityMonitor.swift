import Foundation
import Network

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
final class AsyncSequenceNetworkPathConnectivityMonitor:
    NetworkPathConnectivityMonitorImplementation,
    @unchecked Sendable
{
    private let source: any NetworkPathUpdateSource
    private let stateStore = ConnectivityStateStore()
    private let lock = NSLock()
    private var isStarted = false
    private var isCancelled = false

    var currentConnectivityState: ConnectivityState? {
        get async {
            stateStore.currentState
        }
    }

    init(monitor: NWPathMonitor) {
        source = AsyncSequenceNetworkPathUpdateSource(monitor: monitor)
    }

    init(source: any NetworkPathUpdateSource) {
        self.source = source
    }

    deinit {
        cancel()
    }

    func waitUntilConnected(timeout: TimeInterval?) async throws {
        try checkNotCancelled()
        let updates = stateStore.updateStream(replayLatest: false)
        startIfNeeded()

        if stateStore.currentState == .connected {
            return
        }

        try await waitForConnectedUpdate(in: updates, timeout: timeout)
    }

    func waitForConnectivityRestoration(timeout: TimeInterval?) async throws {
        try checkNotCancelled()
        let updates = stateStore.updateStream(replayLatest: false)
        startIfNeeded()
        try await waitForConnectedUpdate(in: updates, timeout: timeout)
    }

    func connectivityStates() -> AsyncStream<ConnectivityState> {
        let stream = stateStore.stream()
        startIfNeeded()
        return stream
    }

    func connectivityStateUpdates() -> AsyncStream<ConnectivityStateUpdate> {
        let stream = stateStore.updateStream()
        startIfNeeded()
        return stream
    }

    func cancel() {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            return
        }
        isCancelled = true
        lock.unlock()

        stateStore.finish()
        source.cancel()
    }

    private func startIfNeeded() {
        lock.lock()
        let shouldStart = !isStarted && !isCancelled
        if shouldStart {
            isStarted = true
        }
        lock.unlock()

        guard shouldStart else { return }

        source.start(
            receiveUpdate: { [weak stateStore] state in
                stateStore?.update(state)
            },
            receiveCompletion: { [weak stateStore] in
                stateStore?.finish()
            }
        )
    }

    private func checkNotCancelled() throws {
        lock.lock()
        let isCancelled = isCancelled
        lock.unlock()

        if isCancelled {
            throw CancellationError()
        }
    }
}
