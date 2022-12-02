
import Foundation

public typealias Parameters = [String:Encodable]
public typealias HTTPHeaders = [String:String]

public protocol NetworkRequest {
    var url: String { get }
    var method: HTTPMethod { get }
    var endpoint: Endpoint { get }
    var headers: HTTPHeaders? { get set }
    var parameters: Parameters? { get }
    var httpBody: Encodable? { get }
    
    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
}

public extension NetworkRequest {
    
    var decoder: JSONDecoder {
        return .init()
    }
    
    var encoder: JSONEncoder {
        return .init()
    }
    
    func asURLRequest() throws -> URLRequest {
        let urlPath = [url, endpoint.path].joined()
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
        if let httpBody {
            if method != .get {
                request.httpBody = try encoder.encode(httpBody)
            } else {
                throw NetworkError.notAllowedRequest
            }
        }
        
        return request
    }
}
