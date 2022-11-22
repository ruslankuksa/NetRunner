
import Foundation

public protocol NetRunner {
    func execute<T: Decodable>(request: NetworkRequest) async throws -> T
}

public extension NetRunner {
    
    func execute<T: Decodable>(request: NetworkRequest) async throws -> T {
        let urlRequest = try request.asURLRequest()
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        try handleResponse(response)
        return try decodeData(data, decoder: request.decoder)
    }
    
    private func handleResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.badResponse
        }
        
        let statusCode = httpResponse.statusCode
        if httpResponse.statusCode >= 400 {
            throw NetworkError.badRequest(HTTPURLResponse.localizedString(forStatusCode: statusCode))
        }
    }
    
    private func decodeData<T: Decodable>(_ data: Data, decoder: JSONDecoder) throws -> T {
        do {
            let response = try decoder.decode(T.self, from: data)
            return response
        } catch {
            throw NetworkError.unableToDecodeResponse
        }
    }
}

