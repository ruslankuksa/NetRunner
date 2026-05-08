
import Foundation

/// Describes whether network connectivity is currently available.
public enum ConnectivityState: Sendable, Equatable, Hashable {
    /// Network connectivity is available.
    case connected
    /// Network connectivity is unavailable or requires a connection.
    ///
    /// `NWPath.Status.unsatisfied` and `NWPath.Status.requiresConnection` both map
    /// to this state.
    case disconnected
}
