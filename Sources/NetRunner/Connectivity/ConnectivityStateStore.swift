import Foundation

final class ConnectivityStateStore: @unchecked Sendable {
    private let lock = NSLock()
    private var latestState: ConnectivityState?
    private var latestUpdate: ConnectivityStateUpdate?
    private var sequence: UInt64 = 0
    private var isFinished = false
    private var stateContinuations: [UUID: AsyncStream<ConnectivityState>.Continuation] = [:]
    private var updateContinuations: [UUID: AsyncStream<ConnectivityStateUpdate>.Continuation] = [:]

    var currentState: ConnectivityState? {
        lock.lock()
        defer { lock.unlock() }
        return latestState
    }

    var currentUpdate: ConnectivityStateUpdate? {
        lock.lock()
        defer { lock.unlock() }
        return latestUpdate
    }

    func stream() -> AsyncStream<ConnectivityState> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            continuation.onTermination = { [weak self] _ in
                self?.removeStateContinuation(id: id)
            }
            addStateContinuation(continuation, id: id)
        }
    }

    func updateStream(replayLatest: Bool = true) -> AsyncStream<ConnectivityStateUpdate> {
        AsyncStream(bufferingPolicy: .unbounded) { continuation in
            let id = UUID()
            continuation.onTermination = { [weak self] _ in
                self?.removeUpdateContinuation(id: id)
            }
            addUpdateContinuation(continuation, id: id, replayLatest: replayLatest)
        }
    }

    func update(_ state: ConnectivityState) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }

        sequence += 1
        let update = ConnectivityStateUpdate(sequence: sequence, state: state)
        let stateChanged = latestState != state
        latestUpdate = update
        if stateChanged {
            latestState = state
        }

        for continuation in updateContinuations.values {
            continuation.yield(update)
        }
        if stateChanged {
            for continuation in stateContinuations.values {
                continuation.yield(state)
            }
        }
        lock.unlock()
    }

    func finish() {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        let stateContinuations = Array(stateContinuations.values)
        let updateContinuations = Array(updateContinuations.values)
        self.stateContinuations.removeAll()
        self.updateContinuations.removeAll()
        lock.unlock()

        for continuation in stateContinuations {
            continuation.finish()
        }
        for continuation in updateContinuations {
            continuation.finish()
        }
    }

    private func addStateContinuation(
        _ continuation: AsyncStream<ConnectivityState>.Continuation,
        id: UUID
    ) {
        lock.lock()
        if isFinished {
            lock.unlock()
            continuation.finish()
            return
        }

        stateContinuations[id] = continuation
        if let latestState {
            continuation.yield(latestState)
        }
        lock.unlock()
    }

    private func addUpdateContinuation(
        _ continuation: AsyncStream<ConnectivityStateUpdate>.Continuation,
        id: UUID,
        replayLatest: Bool
    ) {
        lock.lock()
        if isFinished {
            lock.unlock()
            continuation.finish()
            return
        }

        updateContinuations[id] = continuation
        if replayLatest, let latestUpdate {
            continuation.yield(latestUpdate)
        }
        lock.unlock()
    }

    private func removeStateContinuation(id: UUID) {
        lock.lock()
        stateContinuations.removeValue(forKey: id)
        lock.unlock()
    }

    private func removeUpdateContinuation(id: UUID) {
        lock.lock()
        updateContinuations.removeValue(forKey: id)
        lock.unlock()
    }
}
