import Foundation

/// Validates URL responses and maps failed responses to thrown errors.
public protocol ResponseValidator: Sendable {
    /// Validates a response and its body.
    func validate(_ response: URLResponse, data: Data) throws
}

/// NetRunner's default HTTP status-code validator.
public struct DefaultResponseValidator: ResponseValidator {
    /// Creates a default response validator.
    public init() {}

    public func validate(_ response: URLResponse, data: Data) throws {
        try HTTPResponseValidator.validate(response, data: data)
    }
}
