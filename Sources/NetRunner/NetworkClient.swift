
import Foundation

/// A concrete `NetRunner` actor that executes requests with an injected session,
/// retry policy, and request/response interceptors.
public actor NetworkClient: NetRunner {

    private let session: any URLSessionProtocol
    private let retryPolicy: RetryPolicy
    private let requestInterceptors: [any RequestInterceptor]
    private let responseInterceptors: [any ResponseInterceptor]

    /// Creates a network client.
    ///
    /// - Parameters:
    ///   - session: The URL session abstraction used to execute data and upload requests.
    ///   - retryPolicy: The retry policy applied to retryable HTTP and transport failures.
    ///   - requestInterceptors: Interceptors applied before each request attempt.
    ///   - responseInterceptors: Interceptors that approve or veto retry attempts.
    public init(
        session: any URLSessionProtocol = URLSession.shared,
        retryPolicy: RetryPolicy = .none,
        requestInterceptors: [any RequestInterceptor] = [],
        responseInterceptors: [any ResponseInterceptor] = []
    ) {
        self.session = session
        self.retryPolicy = retryPolicy
        self.requestInterceptors = requestInterceptors
        self.responseInterceptors = responseInterceptors
    }

    // MARK: - NetRunner conformance

    /// Executes a request and decodes its successful response body.
    public func execute<T: Decodable>(request: any NetworkRequest) async throws -> T {
        let data = try await performRequest(request)
        return try Self.decodeData(data, decoder: request.decoder)
    }

    /// Executes a request that does not require a decoded response body.
    public func send(request: any NetworkRequest) async throws {
        _ = try await performRequest(request)
    }

    /// Uploads a body and decodes the successful response body.
    public nonisolated func upload<T: Decodable>(
        request: any UploadRequest,
        responseType: T.Type = T.self
    ) -> AsyncThrowingStream<UploadEvent<T>, Error> {
        let decoder = request.decoder
        return makeUploadStream(request: request) { data in
            try Self.decodeData(data, decoder: decoder)
        }
    }

    /// Uploads a body without decoding a response body.
    public nonisolated func upload(
        request: any UploadRequest
    ) -> AsyncThrowingStream<UploadEvent<Void>, Error> {
        makeUploadStream(request: request) { _ in () }
    }

    /// Validates an HTTP response using NetRunner's default status-code mapping.
    public nonisolated func validate(_ response: URLResponse) throws {
        try HTTPResponseValidator.validate(response)
    }

    // MARK: - Private

    private func performRequest(_ networkRequest: any NetworkRequest) async throws -> Data {
        let baseRequest = try networkRequest.makeURLRequest()

        return try await performWithRetry(
            makeRequest: {
                try await requestAfterInterceptors(baseRequest)
            },
            operation: { urlRequest, _ in
                try await session.data(for: urlRequest)
            }
        )
    }

    private func requestAfterInterceptors(_ request: URLRequest) async throws -> URLRequest {
        var interceptedRequest = request
        for interceptor in requestInterceptors {
            interceptedRequest = try await interceptor.intercept(interceptedRequest)
        }
        return interceptedRequest
    }

    private nonisolated func makeUploadStream<T>(
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

        let baseRequest = preparedUpload.request

        return try await performWithRetry(
            makeRequest: {
                try await requestAfterInterceptors(baseRequest)
            },
            operation: { urlRequest, attemptIndex in
                try await session.upload(
                    for: urlRequest,
                    fromFile: preparedUpload.fileURL
                ) { bytesSent, totalBytesExpectedToSend in
                    progress(
                        UploadProgress(
                            bytesSent: bytesSent,
                            totalBytesExpectedToSend: totalBytesExpectedToSend,
                            attemptIndex: attemptIndex
                        )
                    )
                }
            }
        )
    }

    private func performWithRetry(
        makeRequest: () async throws -> URLRequest,
        operation: (URLRequest, Int) async throws -> (Data, URLResponse)
    ) async throws -> Data {
        var attemptIndex = 0
        while true {
            try Task.checkCancellation()
            let urlRequest = try await makeRequest()
            do {
                let (data, response) = try await operation(urlRequest, attemptIndex)
                try validate(response)
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let networkError = error as? NetworkError ?? NetworkError(error)
                let shouldRetryByPolicy = attemptIndex < retryPolicy.maxAttempts
                    && retryPolicy.isRetryable(error: networkError)

                guard shouldRetryByPolicy else {
                    throw networkError
                }

                let context = RetryContext(
                    request: urlRequest,
                    attemptIndex: attemptIndex,
                    error: networkError
                )
                let allApprove = await allResponseInterceptorsApprove(context: context)
                guard allApprove else {
                    throw networkError
                }

                try await sleepBeforeRetry(attempt: attemptIndex)
                attemptIndex += 1
            }
        }
    }

    private func sleepBeforeRetry(attempt: Int) async throws {
        let delaySeconds = retryPolicy.delay(forAttempt: attempt)
        if delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }
    }

    private func allResponseInterceptorsApprove(context: RetryContext) async -> Bool {
        for interceptor in responseInterceptors {
            if await !interceptor.shouldRetry(context: context) {
                return false
            }
        }
        return true
    }

    private static func decodeData<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
