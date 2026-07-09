import Foundation

/// A query parameter value NetRunner can encode into a URL query item.
public enum QueryValue: Equatable, Sendable {
    /// A string value.
    case string(String)
    /// An integer value.
    case int(Int)
    /// A floating-point value.
    case double(Double)
    /// A boolean value.
    case bool(Bool)
    /// A repeated query value.
    case array([QueryValue])

    var stringValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .array:
            return ""
        }
    }
}

extension QueryValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension QueryValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension QueryValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension QueryValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension QueryValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: QueryValue...) {
        self = .array(elements)
    }
}
