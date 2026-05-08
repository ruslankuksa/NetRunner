import Foundation
import Network

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
final class AsyncSequenceNetworkPathConnectivityMonitor:
    NetworkPathConnectivityMonitorImplementation,
    @unchecked Sendable
{
    private let monitor: NWPathMonitor
    private let waiterStore = ConnectivityWaiterStore()
    private let stateStore = ConnectivityStateStore()
    private let lock = NSLock()
    private var observationTask: Task<Void, Never>?
    private var isCancelled = false
    
    var currentConnectivityState: ConnectivityState? {
        get async {
            stateStore.currentState
        }
    }

    init(monitor: NWPathMonitor) {
        self.monitor = monitor
    }

    deinit {
        cancel()
    }

    func waitUntilConnected(timeout: TimeInterval?) async throws {
        try checkNotCancelled()
        startIfNeeded()

        if waiterStore.currentIsConnected {
            return
        }

        try await waiterStore.waitUntilConnected(timeout: timeout)
    }

    func waitForConnectivityRestoration(timeout: TimeInterval?) async throws {
        try checkNotCancelled()
        startIfNeeded()
        try await waiterStore.waitForConnectivityRestoration(timeout: timeout)
    }

    func connectivityStates() -> AsyncStream<ConnectivityState> {
        startIfNeeded()
        return stateStore.stream()
    }

    func cancel() {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            return
        }
        isCancelled = true
        let task = observationTask
        observationTask = nil
        lock.unlock()

        task?.cancel()
        monitor.cancel()
        waiterStore.resumeWaiters(throwing: CancellationError())
        stateStore.finish()
    }

    private func startIfNeeded() {
        lock.lock()
        let shouldStart = observationTask == nil && !isCancelled
        if shouldStart {
            observationTask = Task { [monitor, weak waiterStore, weak stateStore] in
                for await path in monitor {
                    guard !Task.isCancelled else { break }
                    guard let waiterStore, let stateStore else { break }
                    Self.updatePath(path, waiterStore: waiterStore, stateStore: stateStore)
                }

                waiterStore?.resumeWaiters(throwing: CancellationError())
                stateStore?.finish()
            }
        }
        lock.unlock()

        if shouldStart {
            Self.updatePath(monitor.currentPath, waiterStore: waiterStore, stateStore: stateStore)
        }
    }

    private func checkNotCancelled() throws {
        lock.lock()
        let isCancelled = isCancelled
        lock.unlock()

        if isCancelled {
            throw CancellationError()
        }
    }

    private static func updatePath(
        _ path: NWPath,
        waiterStore: ConnectivityWaiterStore,
        stateStore: ConnectivityStateStore
    ) {
        let isConnected = path.status == .satisfied
        waiterStore.updateConnectivity(isConnected)
        stateStore.update(isConnected ? .connected : .disconnected)
    }
}
