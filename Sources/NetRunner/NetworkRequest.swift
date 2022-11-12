
import Foundation

typealias Parameters = [String:Any]
typealias Headers = [String:String]

protocol URLRequestConvertible {
    func makeURLRequest() throws -> URLRequest
}

protocol NetworkRequest: URLRequestConvertible {
    var url: String { get }
    var method: HTTPMethod { get }
    var endpoint: Endpoint { get }
    var parameters: Parameters? { get set }
    var headers: Headers { get set }
    var body: Data? { get set }
}

extension NetworkRequest {
    func makeURLRequest() throws -> URLRequest {
        guard let url = URL(string: [url, endpoint.path].joined()) else {
            throw NetworkError.badURL
        }
        
        return URLRequest(url: url)
    }
}

protocol Endpoint {
    var path: String { get }
}

enum HTTPMethod: String {
    
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
