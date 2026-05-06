
import Foundation

public typealias UploadProgressHandler = @Sendable (_ bytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void

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

private final class UploadTaskProgressDelegate: NSObject, URLSessionTaskDelegate {
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
