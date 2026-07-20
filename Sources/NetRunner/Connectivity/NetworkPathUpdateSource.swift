import Foundation
import Network

protocol NetworkPathUpdateSource: Sendable {
    func start(
        receiveUpdate: @escaping @Sendable (ConnectivityState) -> Void,
        receiveCompletion: @escaping @Sendable () -> Void
    )

    func cancel()
}

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
final class AsyncSequenceNetworkPathUpdateSource: NetworkPathUpdateSource, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let lock = NSLock()
    private var observationTask: Task<Void, Never>?
    private var isCancelled = false

    init(monitor: NWPathMonitor) {
        self.monitor = monitor
    }

    func start(
        receiveUpdate: @escaping @Sendable (ConnectivityState) -> Void,
        receiveCompletion: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        guard observationTask == nil, !isCancelled else {
            lock.unlock()
            return
        }

        observationTask = Task { [monitor] in
            for await path in monitor {
                guard !Task.isCancelled else { break }
                receiveUpdate(Self.connectivityState(for: path))
            }
            receiveCompletion()
        }
        lock.unlock()
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
    }

    private static func connectivityState(for path: NWPath) -> ConnectivityState {
        path.status == .satisfied ? .connected : .disconnected
    }
}

final class PathUpdateHandlerNetworkPathUpdateSource: NetworkPathUpdateSource, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var isStarted = false
    private var isCancelled = false

    init(monitor: NWPathMonitor, queue: DispatchQueue) {
        self.monitor = monitor
        self.queue = queue
    }

    func start(
        receiveUpdate: @escaping @Sendable (ConnectivityState) -> Void,
        receiveCompletion _: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        guard !isStarted, !isCancelled else {
            lock.unlock()
            return
        }
        isStarted = true
        monitor.pathUpdateHandler = { path in
            receiveUpdate(Self.connectivityState(for: path))
        }
        monitor.start(queue: queue)
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        guard !isCancelled else {
            lock.unlock()
            return
        }
        isCancelled = true
        monitor.pathUpdateHandler = nil
        lock.unlock()

        monitor.cancel()
    }

    private static func connectivityState(for path: NWPath) -> ConnectivityState {
        path.status == .satisfied ? .connected : .disconnected
    }
}
