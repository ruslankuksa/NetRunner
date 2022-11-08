
import Foundation

enum NetworkError: LocalizedError {
    case badURL
    case badRequest(String)
    case badResponse
    case unableToDecodeResponse
}
