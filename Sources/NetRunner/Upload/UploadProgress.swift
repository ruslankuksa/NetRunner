import Foundation

/// Progress emitted while an upload is in flight.
///
/// Progress reflects bytes sent on the wire for the current attempt only;
/// `attemptIndex` resets to a new attempt's counter on retry. Inter-attempt
/// ordering of progress events is best-effort because they are delivered from
/// `URLSession`'s delegate queue and may interleave with the final `.response`
/// event near completion.
public struct UploadProgress: Equatable, Sendable {
    /// Cumulative bytes sent so far for the current attempt.
    public let bytesSent: Int64
    /// Total bytes expected to be sent for the current attempt, or `-1` if unknown.
    public let totalBytesExpectedToSend: Int64
    /// Zero-based retry attempt index. Increments only when the request is retried.
    public let attemptIndex: Int

    /// Fraction in the range `0...1`, or `0` when the total size is unknown.
    public var fractionCompleted: Double {
        guard totalBytesExpectedToSend > 0 else { return 0 }
        return min(1, max(0, Double(bytesSent) / Double(totalBytesExpectedToSend)))
    }

    public init(bytesSent: Int64, totalBytesExpectedToSend: Int64, attemptIndex: Int) {
        self.bytesSent = bytesSent
        self.totalBytesExpectedToSend = totalBytesExpectedToSend
        self.attemptIndex = attemptIndex
    }
}
