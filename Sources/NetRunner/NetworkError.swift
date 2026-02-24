
import Foundation

public enum NetworkError: LocalizedError, Equatable {
    case badURL
    case badRequest(String)
    case badResponse
    case unableToDecodeResponse(Error)
    case notAllowedRequest
    case notAuthorized
    case timeout
    case noConnectivity
    case serverError(statusCode: Int)
    case clientError(statusCode: Int)

    public var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid URL"
        case .badRequest(let message):
            return "Unsuccessful request: \(message)"
        case .badResponse:
            return "Invalid response."
        case .unableToDecodeResponse(let error):
            return "Unable to decode received data: \(error)"
        case .notAllowedRequest:
            return "HTTP Body is not allowed in GET request"
        case .notAuthorized:
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
        case (.badURL, .badURL): return true
        case (.badRequest(let a), .badRequest(let b)): return a == b
        case (.badResponse, .badResponse): return true
        case (.notAllowedRequest, .notAllowedRequest): return true
        case (.notAuthorized, .notAuthorized): return true
        case (.timeout, .timeout): return true
        case (.noConnectivity, .noConnectivity): return true
        case (.serverError(let a), .serverError(let b)): return a == b
        case (.clientError(let a), .clientError(let b)): return a == b
        case (.unableToDecodeResponse, .unableToDecodeResponse): return true
        default: return false
        }
    }

    public static func mapURLError(_ error: Error) -> NetworkError {
        guard let urlError = error as? URLError else {
            return .badRequest(error.localizedDescription)
        }
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .noConnectivity
        default:
            return .badRequest(urlError.localizedDescription)
        }
    }
}
