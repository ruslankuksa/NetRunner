
import Foundation

internal enum HTTPResponseValidator {
    static func validate(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        let statusCode = httpResponse.statusCode
        func makeErrorResponse() -> HTTPErrorResponse {
            HTTPErrorResponse(
                statusCode: statusCode,
                body: data,
                headers: httpResponse.headerFields
            )
        }

        switch statusCode {
        case 200..<300:
            return
        case 401:
            throw NetworkError.unauthorized(response: makeErrorResponse())
        case 400..<500:
            throw NetworkError.clientError(response: makeErrorResponse())
        case 500..<600:
            throw NetworkError.serverError(response: makeErrorResponse())
        default:
            throw NetworkError.unexpectedStatusCode(response: makeErrorResponse())
        }
    }
}

private extension HTTPURLResponse {
    var headerFields: [String: String] {
        allHeaderFields.reduce(into: [String: String]()) { headers, field in
            guard let name = field.key as? String else { return }
            headers[name] = String(describing: field.value)
        }
    }
}
