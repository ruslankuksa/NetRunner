
import Foundation

public enum NetworkError: LocalizedError {
    case badURL
    case badRequest(String)
    case badResponse
    case unableToDecodeResponse(Error)
    case notAllowedRequest
    
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
        }
    }
}
