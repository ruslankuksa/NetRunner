/// Provides ordered, evaluated connectivity callbacks.
public protocol ConnectivityStateUpdateProviding: ConnectivityStateProviding {
    /// Returns a lossless stream of evaluated connectivity callbacks.
    ///
    /// Every callback receives a strictly increasing sequence number, including
    /// callbacks whose state is equivalent to the preceding callback. New
    /// subscribers receive the latest evaluated update immediately when one exists.
    func connectivityStateUpdates() -> AsyncStream<ConnectivityStateUpdate>
}
