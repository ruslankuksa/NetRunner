import Foundation

/// Encodes an `Encodable` request body into bytes.
///
/// Implementations must be safe to use from concurrent requests.
public protocol RequestBodyEncoder: Sendable {
    /// The content type to apply when the request does not already define one.
    var contentType: String? { get }

    /// Encodes `value` into request body data.
    func encode(_ value: any Encodable & Sendable) throws -> Data
}

/// Decodes response body bytes into a concrete `Decodable` value.
///
/// Implementations must be safe to use from concurrent requests.
public protocol ResponseBodyDecoder: Sendable {
    /// Decodes a value of `type` from `data`.
    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

/// A request body encoder backed by `JSONEncoder`.
public struct JSONRequestBodyEncoder: RequestBodyEncoder {
    /// The JSON encoder used to encode request bodies.
    public let encoder: JSONEncoder
    /// The content type to apply when the request does not already define one.
    public let contentType: String?

    /// Creates a JSON request body encoder.
    public init(
        encoder: JSONEncoder = JSONEncoder(),
        contentType: String? = "application/json"
    ) {
        self.encoder = encoder
        self.contentType = contentType
    }

    /// Encodes `value` into JSON request body data.
    public func encode(_ value: any Encodable & Sendable) throws -> Data {
        try encoder.encode(value)
    }
}

/// A response body decoder backed by `JSONDecoder`.
public struct JSONResponseBodyDecoder: ResponseBodyDecoder {
    /// The JSON decoder used to decode response bodies.
    public let decoder: JSONDecoder

    /// Creates a JSON response body decoder.
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    /// Decodes a value of `type` from JSON response body data.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}
