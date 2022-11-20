
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

public protocol URLRequestConvertible {
    func convertToURLRequest() throws -> URLRequest
    func convertToURLRequest(with parameters: Parameters?) throws -> URLRequest
    func convertToURLRequest<Parameters: Encodable>(_ parameters: Parameters, encoder: JSONEncoder) throws -> URLRequest
}

public protocol Endpoint {
    var path: String { get }
}

public protocol NetworkRequest: URLRequestConvertible {
    var url: String { get }
    var method: HTTPMethod { get }
    var endpoint: Endpoint { get }
    var headers: HTTPHeaders? { get set }
}

public extension NetworkRequest {
    
    var urlPath: String {
        return [url, endpoint.path].joined()
    }
    
    func convertToURLRequest() throws -> URLRequest {
        guard let url = URL(string: urlPath) else {
            throw NetworkError.badURL
        }
        
        return URLRequest(url: url, httpMethod: method, headers: headers)
    }
    
    func convertToURLRequest<Parameters: Encodable>(_ parameters: Parameters, encoder: JSONEncoder = .init()) throws -> URLRequest {
        var request = try convertToURLRequest()
        let httpBody = try encoder.encode(parameters)
        request.httpBody = httpBody
        
        if request.allHTTPHeaderFields?["Content-Type"] == nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    func convertToURLRequest(with parameters: Parameters?) throws -> URLRequest {
        guard let parameters = parameters, !parameters.isEmpty else {
            return try convertToURLRequest()
        }
        
        var components = URLComponents(string: urlPath)
        let nonNilParameters = parameters.compactMapValues { $0 }
        let queryItems = nonNilParameters.map {
            URLQueryItem(name: $0, value: String(describing: $1))
        }
        components?.queryItems = queryItems
        
        var urlRequest = try convertToURLRequest()
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
