import Foundation
@testable import NetRunner

final class ControllableNetworkPathUpdateSource: NetworkPathUpdateSource, @unchecked Sendable {
    private let lock = NSLock()
    private let updatesOnStart: [ConnectivityState]
    private var receiveUpdate: (@Sendable (ConnectivityState) -> Void)?
    private var receiveCompletion: (@Sendable () -> Void)?
    private var _isStarted = false
    private var _isCancelled = false

    var isStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isStarted
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isCancelled
    }

    init(updatesOnStart: [ConnectivityState] = []) {
        self.updatesOnStart = updatesOnStart
    }

    func start(
        receiveUpdate: @escaping @Sendable (ConnectivityState) -> Void,
        receiveCompletion: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        guard !_isStarted, !_isCancelled else {
            lock.unlock()
            return
        }
        _isStarted = true
        self.receiveUpdate = receiveUpdate
        self.receiveCompletion = receiveCompletion
        let updates = updatesOnStart
        lock.unlock()

        for update in updates {
            receiveUpdate(update)
        }
    }

    func send(_ state: ConnectivityState) {
        lock.lock()
        let receiveUpdate = receiveUpdate
        lock.unlock()

        receiveUpdate?(state)
    }

    func finish() {
        lock.lock()
        let receiveCompletion = receiveCompletion
        self.receiveCompletion = nil
        self.receiveUpdate = nil
        lock.unlock()

        receiveCompletion?()
    }

    func cancel() {
        lock.lock()
        _isCancelled = true
        receiveCompletion = nil
        receiveUpdate = nil
        lock.unlock()
    }
}
