
import Foundation

/// Defines how array parameters should be encoded in URL query strings
public enum ArrayEncoding: Sendable {
    /// Encodes arrays with brackets: `key[]=1&key[]=2&key[]=3`
    /// This is the most common format used by Rails and similar frameworks
    case brackets

    /// Encodes arrays without brackets: `key=1&key=2&key=3`
    case noBrackets

    /// Encodes arrays as comma-separated values: `key=1,2,3`
    case commaSeparated
}
