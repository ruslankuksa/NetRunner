/// Provides an asynchronous stream of connectivity state changes.
public protocol ConnectivityStateProviding: Sendable {
    /// The latest known connectivity state, or `nil` before the first state is observed.
    var currentConnectivityState: ConnectivityState? { get async }

    /// Returns a stream that emits connectivity state changes.
    ///
    /// New subscribers receive the latest known state immediately when one exists.
    func connectivityStates() -> AsyncStream<ConnectivityState>
}
