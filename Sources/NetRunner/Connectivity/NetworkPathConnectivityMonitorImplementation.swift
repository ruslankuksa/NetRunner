import Foundation

protocol NetworkPathConnectivityMonitorImplementation:
    CancellableConnectivityMonitor,
    ConnectivityStateUpdateProviding
{}

extension NetworkPathConnectivityMonitorImplementation {
    func waitForConnectedUpdate(
        in updates: AsyncStream<ConnectivityStateUpdate>,
        timeout: TimeInterval?
    ) async throws {
        guard let timeout else {
            try await waitForConnectedUpdate(in: updates)
            return
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.waitForConnectedUpdate(in: updates)
            }
            group.addTask {
                try await Self.sleep(seconds: timeout)
                try Task.checkCancellation()
                throw NetworkError.noConnectivity
            }

            do {
                _ = try await group.next()
                group.cancelAll()
                try Task.checkCancellation()
            } catch {
                group.cancelAll()
                try Task.checkCancellation()
                throw error
            }
        }
    }

    private func waitForConnectedUpdate(
        in updates: AsyncStream<ConnectivityStateUpdate>
    ) async throws {
        for await update in updates {
            try Task.checkCancellation()
            if update.state == .connected {
                return
            }
        }

        throw CancellationError()
    }

    private static func sleep(seconds: TimeInterval) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
