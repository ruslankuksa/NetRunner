
import Foundation

/// Query parameters for a network request.
public typealias QueryParameters = [String: Any]

/// Describes a single HTTP request: base URL, endpoint path, method, headers,
/// query parameters, and optional body.
public protocol NetworkRequest {
    associatedtype Route: Endpoint

    var baseURL: URL { get }
    var method: HTTPMethod { get }
    var endpoint: Route { get }
    var headers: [String: String]? { get set }
    var parameters: QueryParameters? { get }
    var httpBody: Encodable? { get }

    var decoder: JSONDecoder { get }
    var encoder: JSONEncoder { get }
    var arrayEncoding: ArrayEncoding { get }
    var cachePolicy: URLRequest.CachePolicy { get }
}

public extension NetworkRequest {

    var decoder: JSONDecoder {
        return .init()
    }

    var encoder: JSONEncoder {
        return .init()
    }

    var arrayEncoding: ArrayEncoding {
        return .brackets
    }

    var cachePolicy: URLRequest.CachePolicy {
        return .useProtocolCachePolicy
    }

    /// Builds a `URLRequest` from this network request's properties.
    func makeURLRequest() throws -> URLRequest {
        let urlPath = baseURL.absoluteString + endpoint.path
        var components = URLComponents(string: urlPath)

        if let parameters = parameters, !parameters.isEmpty {
            components?.queryItems = buildQueryItems(from: parameters, encoding: arrayEncoding)
        }

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, method: method, headers: headers)
        request.cachePolicy = cachePolicy
        if let httpBody {
            if method != .get {
                request.httpBody = try encoder.encode(httpBody)
            } else {
                throw NetworkError.httpBodyNotAllowedForGET
            }
        }

        return request
    }

    private func buildQueryItems(from parameters: QueryParameters, encoding: ArrayEncoding) -> [URLQueryItem] {
        var queryItems: [URLQueryItem] = []

        for (key, value) in parameters {
            if let array = value as? [Any] {
                // Handle array values based on encoding type
                switch encoding {
                case .brackets:
                    // key[]=1&key[]=2&key[]=3
                    for item in array {
                        queryItems.append(URLQueryItem(name: key, value: "\(item)"))
                    }
                case .noBrackets:
                    // Remove brackets if present in key
                    let cleanKey = key.replacingOccurrences(of: "[]", with: "")
                    for item in array {
                        queryItems.append(URLQueryItem(name: cleanKey, value: "\(item)"))
                    }
                case .commaSeparated:
                    // key=1,2,3
                    let cleanKey = key.replacingOccurrences(of: "[]", with: "")
                    let commaSeparatedValue = array.map { "\($0)" }.joined(separator: ",")
                    queryItems.append(URLQueryItem(name: cleanKey, value: commaSeparatedValue))
                }
            } else {
                // Handle single values normally
                queryItems.append(URLQueryItem(name: key, value: "\(value)"))
            }
        }

        return queryItems
    }
}
