import Foundation

/// A type that executes NetRunner requests.
public protocol NetRunner: Sendable {
    /// Executes a request and decodes the response into the specified `Decodable` type.
    func execute<T: Decodable>(request: any NetworkRequest) async throws -> T

    /// Executes a request without decoding a response body.
    func execute(request: any NetworkRequest) async throws

    /// Uploads a request and decodes the response into the specified `Decodable`
    /// and `Sendable` type.
    func upload<T: Decodable & Sendable>(
        request: any UploadRequest,
        responseType: T.Type
    ) -> AsyncThrowingStream<UploadEvent<T>, Error>

    /// Uploads a request without decoding a response body.
    func upload(request: any UploadRequest) -> AsyncThrowingStream<UploadEvent<Void>, Error>
}
