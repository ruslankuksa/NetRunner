
import Foundation

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
public actor NetworkClient: NetRunner {

    private let session: any URLSessionProtocol
    private let retryPolicy: RetryPolicy
    private let requestInterceptors: [any RequestInterceptor]
    private let responseInterceptors: [any ResponseInterceptor]

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

    public func execute<T: Decodable>(request: any NetworkRequest) async throws -> T {
        let data = try await performRequest(request)
        return try decodeData(data, decoder: request.decoder)
    }

    public func send(request: any NetworkRequest) async throws {
        _ = try await performRequest(request)
    }

    public nonisolated func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        let statusCode = httpResponse.statusCode
        switch statusCode {
        case 200..<300:
            return
        case 401:
            throw NetworkError.unauthorized
        case 400..<500:
            throw NetworkError.clientError(statusCode: statusCode)
        case 500..<600:
            throw NetworkError.serverError(statusCode: statusCode)
        default:
            throw NetworkError.requestFailed(HTTPURLResponse.localizedString(forStatusCode: statusCode))
        }
    }

    // MARK: - Private

    private func performRequest(_ networkRequest: any NetworkRequest) async throws -> Data {
        var urlRequest = try networkRequest.makeURLRequest()

        // Apply request interceptors left-to-right
        for interceptor in requestInterceptors {
            urlRequest = try await interceptor.intercept(urlRequest)
        }

        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: urlRequest)
                try validate(response)
                return data
            } catch let networkError as NetworkError {
                let shouldRetryByPolicy = attempt < retryPolicy.maxAttempts
                    && retryPolicy.isRetryable(error: networkError)

                guard shouldRetryByPolicy else {
                    throw networkError
                }

                let context = RetryContext(
                    request: urlRequest,
                    attemptIndex: attempt,
                    error: networkError
                )
                let allApprove = await allResponseInterceptorsApprove(context: context)
                guard allApprove else {
                    throw networkError
                }

                let delaySeconds = retryPolicy.delay(forAttempt: attempt)
                if delaySeconds > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
                attempt += 1
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw NetworkError(error)
            }
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

    private func decodeData<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
