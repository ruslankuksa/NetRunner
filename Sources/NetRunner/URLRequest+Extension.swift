
import Foundation

extension URLRequest {
    public init(url: URL, httpMethod: HTTPMethod, headers: HTTPHeaders? = nil) {
        self.init(url: url)
        
        self.httpMethod = httpMethod.rawValue
        self.allHTTPHeaderFields = headers
    }
}
