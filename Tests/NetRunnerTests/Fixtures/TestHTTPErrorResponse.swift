import Foundation
@testable import NetRunner

func makeTestHTTPErrorResponse(
    statusCode: Int,
    body: Data = Data(),
    headers: [String: String] = [:]
) -> HTTPErrorResponse {
    HTTPErrorResponse(statusCode: statusCode, body: body, headers: headers)
}
