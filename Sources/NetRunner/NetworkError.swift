
import Foundation

enum NetworkError: LocalizedError {
    case badURL
    case badRequest(String)
    case badResponse
    case unableToDecodeResponse
    
    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid URL"
        case .badRequest(let message):
            return "Unsuccessful request: \(message)"
        case .badResponse:
            return "Invalid response."
        case .unableToDecodeResponse:
            return "Unable to decode received data."
        }
    }
}
