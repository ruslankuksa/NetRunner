import Foundation

/// A URL path used by an `Endpoint`.
///
/// `RequestPath` contains only path text. It must not contain a scheme, host,
/// query, or fragment; those parts belong to `NetworkRequest.baseURL` and
/// `NetworkRequest.parameters`.
public struct RequestPath: Equatable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The raw path text.
    public let rawValue: String

    /// Creates a request path.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates a request path from a string literal.
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
