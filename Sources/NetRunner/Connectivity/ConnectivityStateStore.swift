import Foundation

final class ConnectivityStateStore: @unchecked Sendable {
    private let lock = NSLock()
    private var latestState: ConnectivityState?
    private var isFinished = false
    private var continuations: [UUID: AsyncStream<ConnectivityState>.Continuation] = [:]

    var currentState: ConnectivityState? {
        lock.lock()
        defer { lock.unlock() }
        return latestState
    }

    func stream() -> AsyncStream<ConnectivityState> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id: id)
            }
            addContinuation(continuation, id: id)
        }
    }

    func update(_ state: ConnectivityState) {
        lock.lock()
        guard !isFinished, latestState != state else {
            lock.unlock()
            return
        }
        latestState = state
        let continuations = Array(continuations.values)
        lock.unlock()

        for continuation in continuations {
            continuation.yield(state)
        }
    }

    func finish() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let continuations = Array(continuations.values)
        self.continuations.removeAll()
        lock.unlock()

        for continuation in continuations {
            continuation.finish()
        }
    }

    private func addContinuation(
        _ continuation: AsyncStream<ConnectivityState>.Continuation,
        id: UUID
    ) {
        lock.lock()
        if isFinished {
            lock.unlock()
            continuation.finish()
            return
        }

        continuations[id] = continuation
        if let latestState {
            continuation.yield(latestState)
        }
        lock.unlock()
    }

    private func removeContinuation(id: UUID) {
        lock.lock()
        continuations.removeValue(forKey: id)
        lock.unlock()
    }
}
