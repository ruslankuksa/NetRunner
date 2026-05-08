

import Foundation

/// HTTP methods supported by `NetworkRequest`.
public enum HTTPMethod: String, Sendable, Hashable {

    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public extension HTTPMethod {
    /// Methods considered eligible for automatic retries by default.
    static let defaultRetryableMethods: Set<HTTPMethod> = [.get, .put, .delete]
}
