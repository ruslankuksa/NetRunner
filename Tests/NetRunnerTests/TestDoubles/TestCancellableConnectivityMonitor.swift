import Foundation
@testable import NetRunner

final class TestCancellableConnectivityMonitor: CancellableConnectivityMonitor, @unchecked Sendable {
    private let lock = NSLock()
    private var cancelCount = 0

    var cancelCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cancelCount
    }

    func waitUntilConnected(timeout: TimeInterval?) async throws {}

    func cancel() {
        lock.lock()
        cancelCount += 1
        lock.unlock()
    }
}
