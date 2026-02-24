
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

    public func execute<T: Decodable>(request: NetworkRequest) async throws -> T {
        let data = try await performRequest(request)
        return try decodeData(data, decoder: request.decoder)
    }

    public func execute(request: NetworkRequest) async throws {
        _ = try await performRequest(request)
    }

    public nonisolated func handleResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        let statusCode = httpResponse.statusCode
        switch statusCode {
        case 200..<300:
            return
        case 401:
            throw NetworkError.notAuthorized
        case 400..<500:
            throw NetworkError.clientError(statusCode: statusCode)
        case 500..<600:
            throw NetworkError.serverError(statusCode: statusCode)
        default:
            throw NetworkError.badRequest(HTTPURLResponse.localizedString(forStatusCode: statusCode))
        }
    }

    // MARK: - Private

    private func performRequest(_ networkRequest: NetworkRequest) async throws -> Data {
        var urlRequest = try networkRequest.asURLRequest()

        // Apply request interceptors left-to-right
        for interceptor in requestInterceptors {
            urlRequest = try await interceptor.adapt(urlRequest)
        }

        var attempt = 0
        while true {
            do {
                let (data, response) = try await session.data(for: urlRequest)
                try handleResponse(response)
                return data
            } catch let networkError as NetworkError {
                let shouldRetryByPolicy = attempt < retryPolicy.maxAttempts
                    && retryPolicy.shouldRetry(error: networkError)

                guard shouldRetryByPolicy else {
                    throw networkError
                }

                let context = RetryContext(
                    request: urlRequest,
                    attemptCount: attempt,
                    error: networkError
                )
                let allApprove = await allResponseInterceptorsApprove(context: context)
                guard allApprove else {
                    throw networkError
                }

                let delay = retryPolicy.delayNanoseconds(forAttempt: attempt)
                if delay > 0 {
                    try await Task.sleep(nanoseconds: delay)
                }
                attempt += 1
            } catch {
                throw NetworkError.mapURLError(error)
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
            throw NetworkError.unableToDecodeResponse(error)
        }
    }
}
