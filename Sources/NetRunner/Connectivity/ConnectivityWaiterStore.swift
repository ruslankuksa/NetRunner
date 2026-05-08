
import Foundation

final class ConnectivityWaiterStore: @unchecked Sendable {
    private let lock = NSLock()
    private var isConnected = false
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    var currentIsConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isConnected
    }

    func waitUntilConnected(timeout: TimeInterval?) async throws {
        try await wait(
            timeout: timeout,
            requiresFutureConnectedUpdate: false
        )
    }

    func waitForConnectivityRestoration(timeout: TimeInterval?) async throws {
        try await wait(
            timeout: timeout,
            requiresFutureConnectedUpdate: true
        )
    }

    func updateConnectivity(_ connected: Bool) {
        lock.lock()
        isConnected = connected
        let continuations = connected ? Array(waiters.values) : []
        if connected {
            waiters.removeAll()
        }
        lock.unlock()

        for continuation in continuations {
            continuation.resume()
        }
    }

    func resumeWaiters(throwing error: Error) {
        lock.lock()
        let continuations = Array(waiters.values)
        waiters.removeAll()
        lock.unlock()

        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    private func wait(
        timeout: TimeInterval?,
        requiresFutureConnectedUpdate: Bool
    ) async throws {
        guard let timeout else {
            try await waitWithoutTimeout(requiresFutureConnectedUpdate: requiresFutureConnectedUpdate)
            return
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.waitWithoutTimeout(
                    requiresFutureConnectedUpdate: requiresFutureConnectedUpdate
                )
            }
            group.addTask {
                try await Self.sleep(seconds: timeout)
                throw NetworkError.noConnectivity
            }

            do {
                _ = try await group.next()
                group.cancelAll()
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func waitWithoutTimeout(requiresFutureConnectedUpdate: Bool) async throws {
        try Task.checkCancellation()

        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let result = addWaiterIfNeeded(
                    id: id,
                    continuation: continuation,
                    requiresFutureConnectedUpdate: requiresFutureConnectedUpdate
                )
                switch result {
                case .success:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .waiting:
                    break
                }
            }
        } onCancel: {
            self.cancelWaiter(id)
        }
    }

    private enum WaiterResult {
        case success
        case cancelled
        case waiting
    }

    private func addWaiterIfNeeded(
        id: UUID,
        continuation: CheckedContinuation<Void, Error>,
        requiresFutureConnectedUpdate: Bool
    ) -> WaiterResult {
        lock.lock()
        defer { lock.unlock() }

        if Task.isCancelled {
            return .cancelled
        }

        if !requiresFutureConnectedUpdate && isConnected {
            return .success
        }

        waiters[id] = continuation
        return .waiting
    }

    private func cancelWaiter(_ id: UUID) {
        lock.lock()
        let continuation = waiters.removeValue(forKey: id)
        lock.unlock()

        continuation?.resume(throwing: CancellationError())
    }

    private static func sleep(seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
