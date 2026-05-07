
import Foundation

/// A URL path component that is composed into a `NetworkRequest`.
///
/// Conform to this protocol to define the path segments of your API.
/// The `path` value is appended to the request's `baseURL` to form the full URL.
public protocol Endpoint: Sendable {
    var path: String { get }
}
