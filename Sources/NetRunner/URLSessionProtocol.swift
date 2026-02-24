
import Foundation

public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

@available(iOS 15, macOS 12, tvOS 15, watchOS 8, *)
extension URLSession: URLSessionProtocol {}
