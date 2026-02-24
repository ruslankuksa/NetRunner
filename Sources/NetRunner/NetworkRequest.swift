
import Foundation

public typealias Parameters = [String:Any]
public typealias HTTPHeaders = [String:String]

public protocol NetworkRequest {
    var url: String { get }
    var method: HTTPMethod { get }
    var endpoint: Endpoint { get }
    var headers: HTTPHeaders? { get set }
    var parameters: Parameters? { get }
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

    func asURLRequest() throws -> URLRequest {
        let urlPath = [url, endpoint.path].joined()
        var components = URLComponents(string: urlPath)

        if let parameters = parameters, !parameters.isEmpty {
            components?.queryItems = buildQueryItems(from: parameters, encoding: arrayEncoding)
        }

        guard let url = components?.url else {
            throw NetworkError.badURL
        }

        var request = URLRequest(url: url, httpMethod: method, headers: headers)
        request.cachePolicy = cachePolicy
        if let httpBody {
            if method != .get {
                request.httpBody = try encoder.encode(httpBody)
            } else {
                throw NetworkError.notAllowedRequest
            }
        }

        return request
    }

    private func buildQueryItems(from parameters: Parameters, encoding: ArrayEncoding) -> [URLQueryItem] {
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
