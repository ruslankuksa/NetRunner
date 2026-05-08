import Foundation
import Network

final class PathUpdateHandlerConnectivityMonitor:
    NetworkPathConnectivityMonitorImplementation,
    @unchecked Sendable
{
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private let waiterStore = ConnectivityWaiterStore()
    private let stateStore = ConnectivityStateStore()
    private let lock = NSLock()
    private var isStarted = false
    private var isCancelled = false
    
    var currentConnectivityState: ConnectivityState? {
        get async {
            stateStore.currentState
        }
    }

    init(monitor: NWPathMonitor, queue: DispatchQueue) {
        self.monitor = monitor
        self.queue = queue
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
        lock.unlock()

        monitor.pathUpdateHandler = nil
        monitor.cancel()
        waiterStore.resumeWaiters(throwing: CancellationError())
        stateStore.finish()
    }

    private func startIfNeeded() {
        lock.lock()
        let shouldStart = !isStarted && !isCancelled
        if shouldStart {
            isStarted = true
        }
        lock.unlock()

        guard shouldStart else { return }

        monitor.pathUpdateHandler = { [weak waiterStore, weak stateStore] path in
            guard let waiterStore, let stateStore else { return }
            Self.updatePath(path, waiterStore: waiterStore, stateStore: stateStore)
        }
        monitor.start(queue: queue)
        Self.updatePath(monitor.currentPath, waiterStore: waiterStore, stateStore: stateStore)
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
