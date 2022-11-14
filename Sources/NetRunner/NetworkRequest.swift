
import Foundation

public typealias Parameters = [String:Encodable]
public typealias HTTPHeaders = [String:String]

extension URLRequest {
    public init(url: URL, httpMethod: HTTPMethod, headers: HTTPHeaders? = nil) {
        self.init(url: url)
        
        self.httpMethod = httpMethod.rawValue
        self.allHTTPHeaderFields = headers
    }
}

protocol URLRequestConvertible {
    func makeURLRequest() throws -> URLRequest
    func makeURLRequest(with parameters: Parameters?) throws -> URLRequest
    func makeURLRequest<Parameters: Encodable>(_ parameters: Parameters, encoder: JSONEncoder) throws -> URLRequest
}

protocol Endpoint {
    var path: String { get }
}

protocol NetworkRequest: URLRequestConvertible {
    var url: String { get }
    var method: HTTPMethod { get }
    var endpoint: Endpoint { get }
    var headers: HTTPHeaders? { get set }
}

extension NetworkRequest {
    
    var urlPath: String {
        return [url, endpoint.path].joined()
    }
    
    func makeURLRequest() throws -> URLRequest {
        guard let url = URL(string: urlPath) else {
            throw NetworkError.badURL
        }
        
        return URLRequest(url: url, httpMethod: method, headers: headers)
    }
    
    func makeURLRequest<Parameters: Encodable>(_ parameters: Parameters, encoder: JSONEncoder = .init()) throws -> URLRequest {
        var request = try makeURLRequest()
        let httpBody = try encoder.encode(parameters)
        request.httpBody = httpBody
        
        if request.allHTTPHeaderFields?["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    func makeURLRequest(with parameters: Parameters?) throws -> URLRequest {
        guard let parameters = parameters, !parameters.isEmpty else {
            return try makeURLRequest()
        }
        
        var components = URLComponents(string: urlPath)
        let nonNilParameters = parameters.compactMapValues { $0 }
        let queryItems = nonNilParameters.map {
            URLQueryItem(name: $0, value: String(describing: $1))
        }
        components?.queryItems = queryItems
        
        var urlRequest = try makeURLRequest()
        urlRequest.url = components?.url
        
        return urlRequest
    }
}

public enum HTTPMethod: String {
    
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
