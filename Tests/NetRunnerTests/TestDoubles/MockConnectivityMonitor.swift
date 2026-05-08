
import Foundation
@testable import NetRunner

actor MockConnectivityMonitor: ConnectivityMonitor, ConnectivityStateProviding {
    private let stateStore = ConnectivityStateStore()
    private let waiterStore = ConnectivityWaiterStore()
    private var waitStartedContinuations: [CheckedContinuation<Void, Never>] = []
    private let waitError: Error?

    private(set) var waitCallCount = 0
    private(set) var capturedTimeouts: [TimeInterval?] = []

    init(waitError: Error? = nil) {
        self.waitError = waitError
    }

    nonisolated var currentConnectivityState: ConnectivityState? {
        stateStore.currentState
    }

    nonisolated func connectivityStates() -> AsyncStream<ConnectivityState> {
        stateStore.stream()
    }

    func waitUntilConnected(timeout: TimeInterval?) async throws {
        waitCallCount += 1
        capturedTimeouts.append(timeout)
        resumeWaitStartedContinuations()

        if let waitError {
            throw waitError
        }

        try await waiterStore.waitUntilConnected(timeout: timeout)
    }

    func waitForWaitCall() async {
        if waitCallCount > 0 {
            return
        }

        await withCheckedContinuation { continuation in
            waitStartedContinuations.append(continuation)
        }
    }

    func connect() {
        stateStore.update(.connected)
        waiterStore.updateConnectivity(true)
    }

    func updateConnectivityState(_ state: ConnectivityState) {
        stateStore.update(state)
    }

    private func resumeWaitStartedContinuations() {
        let continuations = waitStartedContinuations
        waitStartedContinuations.removeAll()

        for continuation in continuations {
            continuation.resume()
        }
    }
}
