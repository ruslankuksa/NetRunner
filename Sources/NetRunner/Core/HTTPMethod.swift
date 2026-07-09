

import Foundation

/// An HTTP method used by `NetworkRequest`.
///
/// NetRunner provides static values for common methods and accepts custom
/// method names through `init(rawValue:)` or string literals.
public struct HTTPMethod: RawRepresentable, Sendable, Hashable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

public extension HTTPMethod {
    static let get = HTTPMethod(rawValue: "GET")
    static let post = HTTPMethod(rawValue: "POST")
    static let put = HTTPMethod(rawValue: "PUT")
    static let patch = HTTPMethod(rawValue: "PATCH")
    static let delete = HTTPMethod(rawValue: "DELETE")

    /// Creates a custom HTTP method.
    static func custom(_ rawValue: String) -> HTTPMethod {
        HTTPMethod(rawValue: rawValue)
    }

    /// Methods considered eligible for automatic retries by default.
    static let defaultRetryableMethods: Set<HTTPMethod> = [.get, .put, .delete]
}
