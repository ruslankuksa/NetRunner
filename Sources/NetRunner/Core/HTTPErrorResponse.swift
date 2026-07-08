import Foundation

/// The HTTP response details captured for a failed HTTP status code.
public struct HTTPErrorResponse: Equatable, Sendable {
    /// The HTTP status code returned by the server.
    public let statusCode: Int
    /// The raw response body returned with the failed HTTP response.
    public let body: Data
    /// The HTTP response headers keyed by their original header names.
    public let headers: [String: String]

    /// Creates HTTP error response details.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned by the server.
    ///   - body: The raw response body returned with the failed HTTP response.
    ///   - headers: The HTTP response headers keyed by their original header names.
    public init(statusCode: Int, body: Data, headers: [String: String]) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
    }

    /// Decodes the response body as text using the provided string encoding.
    ///
    /// - Parameter encoding: The string encoding used to decode the body.
    /// - Returns: A string when the response body can be decoded using `encoding`.
    public func bodyText(encoding: String.Encoding = .utf8) -> String? {
        String(data: body, encoding: encoding)
    }
}
