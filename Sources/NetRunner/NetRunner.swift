
import Foundation

public protocol NetRunner {
    func execute<T: Decodable>(request: NetworkRequest) async throws -> T
    func execute(request: NetworkRequest) async throws
    func handleResponse(_ response: URLResponse) throws
}

public extension NetRunner {
    
    func execute<T: Decodable>(request: NetworkRequest) async throws -> T {
        let urlRequest = try request.asURLRequest()
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        try handleResponse(response)
        return try decodeData(data, decoder: request.decoder)
    }
    
    func execute(request: NetworkRequest) async throws {
        let urlRequest = try request.asURLRequest()
        let (_, response) = try await URLSession.shared.data(for: urlRequest)
        
        try handleResponse(response)
    }
    
    func handleResponse(_ response: URLResponse) throws {
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
    
    private func decodeData<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
        do {
            let response = try decoder.decode(T.self, from: data)
            return response
        } catch {
            throw NetworkError.unableToDecodeResponse(error)
        }
    }
}

