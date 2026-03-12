
import Foundation

/// Errors that can occur during network request execution.
public enum NetworkError: LocalizedError, Equatable, Sendable {
    /// The constructed URL is not valid.
    case invalidURL
    /// The request failed with an unexpected status code or error.
    case requestFailed(String)
    /// The server returned a response that is not a valid HTTP response.
    case invalidResponse
    /// The response data could not be decoded into the expected type.
    case decodingFailed(any Error & Sendable)
    /// An HTTP body was set on a GET request, which is not allowed.
    case httpBodyNotAllowedForGET
    /// The server returned HTTP 401 Unauthorized.
    case unauthorized
    /// The request timed out.
    case timeout
    /// The device has no network connectivity.
    case noConnectivity
    /// The server returned a 5xx status code.
    case serverError(statusCode: Int)
    /// The server returned a 4xx status code (other than 401).
    case clientError(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed(let message):
            return "Request failed: \(message)"
        case .invalidResponse:
            return "Invalid response."
        case .decodingFailed(let error):
            return "Unable to decode received data: \(error)"
        case .httpBodyNotAllowedForGET:
            return "HTTP Body is not allowed in GET request"
        case .unauthorized:
            return "Not authorized"
        case .timeout:
            return "The request timed out"
        case .noConnectivity:
            return "No network connectivity"
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .clientError(let statusCode):
            return "Client error: \(statusCode)"
        }
    }

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.requestFailed(let a), .requestFailed(let b)): return a == b
        case (.invalidResponse, .invalidResponse): return true
        case (.httpBodyNotAllowedForGET, .httpBodyNotAllowedForGET): return true
        case (.unauthorized, .unauthorized): return true
        case (.timeout, .timeout): return true
        case (.noConnectivity, .noConnectivity): return true
        case (.serverError(let a), .serverError(let b)): return a == b
        case (.clientError(let a), .clientError(let b)): return a == b
        case (.decodingFailed, .decodingFailed): return true
        default: return false
        }
    }

    /// Creates a `NetworkError` from a generic `Error`, mapping known `URLError` codes
    /// to specific cases.
    public init(_ error: Error) {
        guard let urlError = error as? URLError else {
            self = .requestFailed(error.localizedDescription)
            return
        }
        switch urlError.code {
        case .timedOut:
            self = .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            self = .noConnectivity
        default:
            self = .requestFailed(urlError.localizedDescription)
        }
    }
}
