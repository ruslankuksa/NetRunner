
import Foundation

/// Adopted by network service types to gain default `execute` and `send` implementations.
public protocol NetRunner {
    /// Executes a request and decodes the response into the specified `Decodable` type.
    func execute<T: Decodable>(request: any NetworkRequest) async throws -> T
    /// Executes a request without decoding a response body (fire-and-forget).
    func send(request: any NetworkRequest) async throws
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

    func validate(_ response: URLResponse) throws {
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

    private func decodeData<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
        do {
            let response = try decoder.decode(T.self, from: data)
            return response
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
