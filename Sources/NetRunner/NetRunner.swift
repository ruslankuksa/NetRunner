
import Foundation

public protocol NetRunner {
    var decoder: JSONDecoder { get }
    func execute<T: Decodable>(request: URLRequest) async throws -> T
}

public extension NetRunner {
    
    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        return decoder
    }
    
    func execute<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        try handleResponse(response)
        return try decodeData(data)
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
    
    private func decodeData<T: Decodable>(_ data: Data) throws -> T {
        do {
            let response = try decoder.decode(T.self, from: data)
            return response
        } catch {
            throw NetworkError.unableToDecodeResponse
        }
    }
}

