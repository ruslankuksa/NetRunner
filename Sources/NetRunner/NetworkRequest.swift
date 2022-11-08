
import Foundation

typealias Parameters = [String:Any]
typealias Headers = [String:String]

protocol NetworkRequest {
    var url: String { get }
    var method: HTTPMethod { get }
    var endpoint: Endpoint { get }
    var parameters: Parameters? { get set }
    var headers: Headers { get set }
    var body: Data? { get set }
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
