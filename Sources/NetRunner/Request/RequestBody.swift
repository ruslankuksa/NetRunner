import Foundation

/// A request body that NetRunner can attach to a `URLRequest`.
public enum RequestBody: Sendable {
    /// A JSON body encoded from an `Encodable` value.
    case json(any Encodable & Sendable, encoder: JSONEncoder? = nil)
    /// A raw data body with an optional content type.
    case data(Data, contentType: String? = nil)
}

extension RequestBody {
    func apply(
        to request: inout URLRequest,
        method: HTTPMethod,
        defaultRequestEncoder: JSONEncoder
    ) throws {
        guard method != .get else {
            throw NetworkError.requestBodyNotAllowedForGET
        }

        switch self {
        case .json(let body, let encoder):
            request.httpBody = try (encoder ?? defaultRequestEncoder).encode(body)
            request.setContentTypeIfMissing("application/json")

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
