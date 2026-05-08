
import Foundation

/// Intercepts outgoing URL requests before they are sent,
/// allowing modification such as adding authentication headers.
public protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}
