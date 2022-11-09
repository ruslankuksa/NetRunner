
import Foundation

protocol NetRunner {
    var decoder: JSONDecoder { get }
    func execute<T: Decodable>(request: NetworkRequest) async throws -> T
}

extension NetRunner {
    
    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        return decoder
    }
    
    func execute<T: Decodable>(request: NetworkRequest) async throws -> T {
        let urlRequest = try makeURLRequest(from: request)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
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
        let decoded = try decoder.decode(T.self, from: data)
        return decoded
    }
    
    private func makeURLRequest(from request: NetworkRequest) throws -> URLRequest {
        let path = [request.url, request.endpoint.path].joined(separator: "")
        var components = URLComponents(string: path)
        
        if let parameters = request.parameters, !parameters.isEmpty {
            let noneNilParameters = parameters.compactMapValues { $0 }
            let queryItems = noneNilParameters.map {
                URLQueryItem(name: $0, value: String(describing: $1))
            }
            components?.queryItems = queryItems
        }
        
        guard let url = components?.url else {
            throw NetworkError.badURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.allHTTPHeaderFields = request.headers
        urlRequest.httpMethod = request.method.rawValue
        
        if let body = request.body {
            urlRequest.httpBody = body
        }
        
        return urlRequest
    }
}

