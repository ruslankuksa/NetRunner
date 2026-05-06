
import Foundation

/// Internal helper that builds a `URLRequest` from the parts shared by
/// `NetworkRequest` and `UploadRequest`.
internal enum URLRequestBuilder {
    static func makeURLRequest(
        baseURL: URL,
        path: String,
        method: HTTPMethod,
        headers: [String: String]?,
        parameters: QueryParameters?,
        arrayEncoding: ArrayEncoding,
        cachePolicy: URLRequest.CachePolicy
    ) throws -> URLRequest {
        var components = URLComponents(string: baseURL.absoluteString + path)

        if let parameters, !parameters.isEmpty {
            components?.queryItems = QueryItemBuilder.buildQueryItems(from: parameters, encoding: arrayEncoding)
        }

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, method: method, headers: headers)
        request.cachePolicy = cachePolicy
        return request
    }
}
