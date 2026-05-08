
import Foundation

/// Adopted by network service types to gain default request and upload implementations.
public protocol NetRunner {
    /// Executes a request and decodes the response into the specified `Decodable` type.
    func execute<T: Decodable>(request: any NetworkRequest) async throws -> T
    /// Executes a request without decoding a response body (fire-and-forget).
    func send(request: any NetworkRequest) async throws
    /// Uploads a request and decodes the response into the specified `Decodable` type.
    func upload<T: Decodable>(
        request: any UploadRequest,
        responseType: T.Type
    ) -> AsyncThrowingStream<UploadEvent<T>, Error>
    /// Uploads a request without decoding a response body.
    func upload(request: any UploadRequest) -> AsyncThrowingStream<UploadEvent<Void>, Error>
    /// Validates the URL response, throwing a `NetworkError` for non-success status codes.
    func validate(_ response: URLResponse) throws
}

public extension NetRunner {

    func execute<T: Decodable>(request: any NetworkRequest) async throws -> T {
        let urlRequest = try request.makeURLRequest()
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        try validate(response)
        return try decodeData(data, decoder: request.decoder)
    }

    func send(request: any NetworkRequest) async throws {
        let urlRequest = try request.makeURLRequest()
        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        try validate(response)
    }

    func upload<T: Decodable>(
        request: any UploadRequest,
        responseType: T.Type = T.self
    ) -> AsyncThrowingStream<UploadEvent<T>, Error> {
        let decoder = request.decoder
        return makeUploadStream(request: request) { data in
            try decodeData(data, decoder: decoder)
        }
    }

    func upload(request: any UploadRequest) -> AsyncThrowingStream<UploadEvent<Void>, Error> {
        makeUploadStream(request: request) { _ in () }
    }

    func validate(_ response: URLResponse) throws {
        try HTTPResponseValidator.validate(response)
    }

    private func makeUploadStream<T>(
        request: any UploadRequest,
        decode: @escaping @Sendable (Data) throws -> T
    ) -> AsyncThrowingStream<UploadEvent<T>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let data = try await performUpload(request) { progress in
                        continuation.yield(.progress(progress))
                    }
                    let response = try decode(data)
                    continuation.yield(.response(response))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func performUpload(
        _ uploadRequest: any UploadRequest,
        progress: @escaping @Sendable (UploadProgress) -> Void
    ) async throws -> Data {
        let preparedUpload = try await Task.detached(priority: .utility) {
            try UploadRequestPreparer.prepare(uploadRequest)
        }.value
        defer {
            UploadRequestPreparer.removeTemporaryFile(for: preparedUpload)
        }

        let (data, response) = try await URLSession.shared.upload(
            for: preparedUpload.request,
            fromFile: preparedUpload.fileURL
        ) { bytesSent, totalBytesExpectedToSend in
            progress(
                UploadProgress(
                    bytesSent: bytesSent,
                    totalBytesExpectedToSend: totalBytesExpectedToSend,
                    attemptIndex: 0
                )
            )
        }
        try validate(response)
        return data
    }

    private func decodeData<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
