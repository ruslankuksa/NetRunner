/// Events emitted by an upload operation.
public enum UploadEvent<Response> {
    /// Progress update for the current attempt.
    case progress(UploadProgress)
    /// The final decoded response (or `Void`) emitted once the upload succeeds.
    case response(Response)
}

extension UploadEvent: Sendable where Response: Sendable {}
