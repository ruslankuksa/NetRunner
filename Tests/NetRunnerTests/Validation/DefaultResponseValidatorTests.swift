import Foundation
import Testing
@testable import NetRunner

struct DefaultResponseValidatorTests {
    @Test func validate200DoesNotThrow() throws {
        let validator = DefaultResponseValidator()
        let response = makeHTTPResponse(statusCode: 200)
        #expect(throws: Never.self) { try validator.validate(response, data: Data()) }
    }

    @Test func validate299DoesNotThrow() throws {
        let validator = DefaultResponseValidator()
        #expect(throws: Never.self) {
            try validator.validate(makeHTTPResponse(statusCode: 299), data: Data())
        }
    }

    @Test func validate401ThrowsUnauthorized() {
        let validator = DefaultResponseValidator()
        #expect(throws: NetworkError.unauthorized(response: makeTestHTTPErrorResponse(statusCode: 401))) {
            try validator.validate(makeHTTPResponse(statusCode: 401), data: Data())
        }
    }

    @Test func validate404ThrowsClientError() {
        let validator = DefaultResponseValidator()
        #expect(throws: NetworkError.clientError(response: makeTestHTTPErrorResponse(statusCode: 404))) {
            try validator.validate(makeHTTPResponse(statusCode: 404), data: Data())
        }
    }

    @Test func validate422ThrowsClientErrorWithBodyAndHeaders() {
        let validator = DefaultResponseValidator()
        let body = Data(#"{"success":false,"message":["Already connected"]}"#.utf8)
        let response = makeHTTPResponse(
            statusCode: 422,
            headerFields: ["X-Request-ID": "request-123"]
        )

        do {
            try validator.validate(response, data: body)
            Issue.record("Expected validation to throw a client error")
        } catch NetworkError.clientError(let errorResponse) {
            #expect(errorResponse.statusCode == 422)
            #expect(errorResponse.body == body)
            #expect(errorResponse.headers["X-Request-ID"] == "request-123")
            #expect(errorResponse.bodyText() == #"{"success":false,"message":["Already connected"]}"#)
        } catch {
            Issue.record("Expected client error, got \(error)")
        }
    }

    @Test func validate503ThrowsServerError() {
        let validator = DefaultResponseValidator()
        #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try validator.validate(makeHTTPResponse(statusCode: 503), data: Data())
        }
    }

    @Test func validate300ThrowsUnexpectedStatusCodeWithBodyAndHeaders() {
        let validator = DefaultResponseValidator()
        let body = Data("use cached response".utf8)
        let response = makeHTTPResponse(
            statusCode: 300,
            headerFields: ["Location": "https://example.com/alternate"]
        )

        do {
            try validator.validate(response, data: body)
            Issue.record("Expected validation to throw an unexpected status code error")
        } catch NetworkError.unexpectedStatusCode(let errorResponse) {
            #expect(errorResponse.statusCode == 300)
            #expect(errorResponse.body == body)
            #expect(errorResponse.headers["Location"] == "https://example.com/alternate")
            #expect(errorResponse.bodyText() == "use cached response")
        } catch {
            Issue.record("Expected unexpected status code error, got \(error)")
        }
    }

    @Test func validateNonHTTPThrowsInvalidResponse() {
        let validator = DefaultResponseValidator()
        let response = URLResponse(
            url: URL(string: "https://example.com")!,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )
        #expect(throws: NetworkError.invalidResponse) {
            try validator.validate(response, data: Data())
        }
    }

    private func makeHTTPResponse(
        statusCode: Int,
        headerFields: [String: String]? = nil
    ) -> URLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        )!
    }
}
