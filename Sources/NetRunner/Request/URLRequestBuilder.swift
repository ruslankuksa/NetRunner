
import Foundation

/// Internal helper that builds a `URLRequest` from the parts shared by
/// `NetworkRequest` and `UploadRequest`.
internal enum URLRequestBuilder {
    static func makeURLRequest(
        baseURL: URL,
        path: RequestPath,
        method: HTTPMethod,
        headers: HTTPHeaders?,
        parameters: QueryParameters?,
        arrayEncoding: ArrayEncoding,
        cachePolicy: URLRequest.CachePolicy
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }

        components.path = try makePath(basePath: components.path, endpointPath: path.rawValue)

        if let parameters, !parameters.isEmpty {
            components.queryItems = QueryItemBuilder.buildQueryItems(from: parameters, encoding: arrayEncoding)
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url, method: method, headers: headers)
        request.cachePolicy = cachePolicy
        return request
    }

    private static func makePath(basePath: String, endpointPath: String) throws -> String {
        guard isValidEndpointPath(endpointPath) else {
            throw NetworkError.invalidURL
        }

        guard !endpointPath.isEmpty else {
            return basePath
        }

        let base = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpoint = endpointPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch (base.isEmpty, endpoint.isEmpty) {
        case (true, true):
            return ""
        case (true, false):
            return "/\(endpoint)"
        case (false, true):
            return "/\(base)"
        case (false, false):
            return "/\(base)/\(endpoint)"
        }
    }

    private static func isValidEndpointPath(_ path: String) -> Bool {
        guard !path.contains("?"), !path.contains("#") else {
            return false
        }

        guard let components = URLComponents(string: path) else {
            return false
        }

        return components.scheme == nil
            && components.host == nil
            && components.query == nil
            && components.fragment == nil
    }
}
