
import Foundation

extension URLRequest {
    /// Creates a URL request with the given URL, HTTP method, and optional headers.
    public init(url: URL, method: HTTPMethod, headers: HTTPHeaders? = nil) {
        self.init(url: url)

        self.httpMethod = method.rawValue
        self.allHTTPHeaderFields = headers
    }
}
