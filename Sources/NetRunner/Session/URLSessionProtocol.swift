
import Foundation

/// Reports upload progress as bytes are sent on the wire.
///
/// - Parameters:
///   - bytesSent: Cumulative bytes sent so far for the current attempt.
///   - totalBytesExpectedToSend: Total bytes the upload expects to send, or `-1` if unknown.
public typealias UploadProgressHandler = @Sendable (_ bytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void

/// A `URLSession`-shaped abstraction used by `NetworkClient` so consumers can
/// inject mocks and instrumentation in tests.
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func upload(
        for request: URLRequest,
        fromFile fileURL: URL,
        progress: @escaping UploadProgressHandler
    ) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {
    public func upload(
        for request: URLRequest,
        fromFile fileURL: URL,
        progress: @escaping UploadProgressHandler
    ) async throws -> (Data, URLResponse) {
        if #available(iOS 15, macOS 12, tvOS 15, watchOS 8, *) {
            let delegate = UploadTaskProgressDelegate(progress: progress)
            return try await upload(for: request, fromFile: fileURL, delegate: delegate)
        }

        let result = try await upload(for: request, fromFile: fileURL)
        reportCompletedUploadProgress(for: fileURL, progress: progress)
        return result
    }

    private func reportCompletedUploadProgress(
        for fileURL: URL,
        progress: UploadProgressHandler
    ) {
        guard let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return
        }
        progress(Int64(fileSize), Int64(fileSize))
    }
}

// `@unchecked Sendable` is justified: the only stored property is an immutable
// `@Sendable` closure, and `URLSession` invokes the delegate from its delegate
// queue without us mutating any shared state.
private final class UploadTaskProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let progress: UploadProgressHandler

    init(progress: @escaping UploadProgressHandler) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        progress(totalBytesSent, totalBytesExpectedToSend)
    }
}
