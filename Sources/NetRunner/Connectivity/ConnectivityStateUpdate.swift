/// An evaluated connectivity callback and its position in the observation sequence.
public struct ConnectivityStateUpdate: Equatable, Sendable {
    /// The strictly increasing sequence number assigned to the callback.
    public let sequence: UInt64

    /// The connectivity state reported by the callback.
    public let state: ConnectivityState

    /// Creates a sequenced connectivity update.
    public init(sequence: UInt64, state: ConnectivityState) {
        self.sequence = sequence
        self.state = state
    }
}
