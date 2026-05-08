import Foundation
import Network

/// A `ConnectivityMonitor` backed by `NWPathMonitor`.
public final class NetworkPathConnectivityMonitor:
    ConnectivityMonitor,
    ConnectivityStateProviding,
    CancellableConnectivityMonitor,
    @unchecked Sendable
{
    private let implementation: any NetworkPathConnectivityMonitorImplementation
    
    public var currentConnectivityState: ConnectivityState? {
        get async {
            await implementation.currentConnectivityState
        }
    }

    public init(
        monitor: NWPathMonitor = NWPathMonitor(),
        queue: DispatchQueue = DispatchQueue(label: "NetRunner.NetworkPathConnectivityMonitor")
    ) {
        if #available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *) {
            implementation = AsyncSequenceNetworkPathConnectivityMonitor(monitor: monitor)
        } else {
            implementation = PathUpdateHandlerConnectivityMonitor(monitor: monitor, queue: queue)
        }
    }

    deinit {
        cancel()
    }

    public func waitUntilConnected(timeout: TimeInterval?) async throws {
        try await implementation.waitUntilConnected(timeout: timeout)
    }

    public func waitForConnectivityRestoration(timeout: TimeInterval?) async throws {
        try await implementation.waitForConnectivityRestoration(timeout: timeout)
    }

    public func connectivityStates() -> AsyncStream<ConnectivityState> {
        implementation.connectivityStates()
    }

    /// Stops path monitoring and finishes any active connectivity streams.
    public func cancel() {
        implementation.cancel()
    }
}
