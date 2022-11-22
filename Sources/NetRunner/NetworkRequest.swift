
import Foundation

public typealias Parameters = [String:Encodable]
public typealias HTTPHeaders = [String:String]

public protocol NetworkRequest {
    var url: String { get }
    var method: HTTPMethod { get }
    var endpoint: Endpoint { get }
    var headers: HTTPHeaders? { get set }
    var parameters: Parameters? { get }
    var body: Encodable? { get }
    
    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
    
    init(method: HTTPMethod, endpoint: Endpoint, parameters: Parameters?, decoder: JSONDecoder)
    init(method: HTTPMethod, endpoint: Endpoint, body: Encodable?, encoder: JSONEncoder, decoder: JSONDecoder)
}

public extension NetworkRequest {
    
    private var urlPath: String {
        return [url, endpoint.path].joined()
    }
    
    func asURLRequest() throws -> URLRequest {
        var components = URLComponents(string: urlPath)
        
        if let parameters = parameters, !parameters.isEmpty {
            components?.queryItems = parameters.map {
                return URLQueryItem(name: $0, value: "\($1)")
            }
        }
        
        guard let url = components?.url else {
            throw NetworkError.badURL
        }
        
        var request = URLRequest(url: url, httpMethod: method, headers: headers)
        if let body = body {
            if method != .get {
                request.httpBody = try encoder.encode(body)
            } else {
                throw NetworkError.notAllowedRequest
            }
        }
        
        return request
    }
}
