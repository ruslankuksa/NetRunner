import Foundation

/// A request body that NetRunner can attach to a `URLRequest`.
public enum RequestBody: Sendable {
    /// A body encoded from an `Encodable` value.
    ///
    /// If `encoder` is omitted, `NetworkClient` uses its default request body
    /// encoder.
    case encoded(any Encodable & Sendable, encoder: (any RequestBodyEncoder)? = nil)
    /// A raw data body with an optional content type.
    case data(Data, contentType: String? = nil)
}

public extension RequestBody {
    /// Creates a JSON body encoded from an `Encodable` value.
    ///
    /// This always uses JSON. It does not inherit `NetworkClient`'s default
    /// request body encoder.
    static func json(
        _ value: any Encodable & Sendable,
        encoder: JSONEncoder? = nil
    ) -> RequestBody {
        .encoded(
            value,
            encoder: JSONRequestBodyEncoder(encoder: encoder ?? JSONEncoder())
        )
    }
}

extension RequestBody {
    func apply(
        to request: inout URLRequest,
        method: HTTPMethod,
        defaultRequestEncoder: any RequestBodyEncoder
    ) throws {
        guard method != .get else {
            throw NetworkError.requestBodyNotAllowedForGET
        }

        switch self {
        case .encoded(let body, let encoder):
            let encoder = encoder ?? defaultRequestEncoder
            request.httpBody = try encoder.encode(body)
            if let contentType = encoder.contentType {
                request.setContentTypeIfMissing(contentType)
            }

        case .data(let data, let contentType):
            request.httpBody = data
            if let contentType {
                request.setContentTypeIfMissing(contentType)
            }
        }
    }
}

private extension URLRequest {
    mutating func setContentTypeIfMissing(_ contentType: String) {
        if value(forHTTPHeaderField: "Content-Type") == nil {
            setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
    }
}
