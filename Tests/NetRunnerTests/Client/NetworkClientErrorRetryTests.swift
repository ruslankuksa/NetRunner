import Foundation
import Testing
@testable import NetRunner

extension NetworkClientTests {
    @Test func execute401ThrowsUnauthorized() async {
        let session = stubbedSession(statusCode: 401)
        let client = makeClient(session: session)

        await #expect(throws: NetworkError.unauthorized(response: makeTestHTTPErrorResponse(statusCode: 401))) {
            try await client.execute(request: TestNetworkRequest())
        }
    }

    @Test func execute404ThrowsClientError() async {
        let session = stubbedSession(statusCode: 404)
        let client = makeClient(session: session)

        await #expect(throws: NetworkError.clientError(response: makeTestHTTPErrorResponse(statusCode: 404))) {
            try await client.execute(request: TestNetworkRequest())
        }
    }

    @Test func execute422ThrowsClientErrorContainingResponseBody() async {
        let body = Data(
            #"""
            {
                "success": false,
                "message": [
                    "This social account is already connected to komlive24+222_42@gmail.com Gipper account(s)."
                ]
            }
            """#.utf8
        )
        let session = stubbedSession(statusCode: 422, data: body)
        let client = makeClient(session: session)

        do {
            try await client.execute(request: TestNetworkRequest())
            Issue.record("Expected request to throw a 422 client error")
        } catch NetworkError.clientError(let response) {
            #expect(response.statusCode == 422)
            #expect(response.body == body)
            #expect(response.bodyText()?.contains("This social account is already connected") == true)
        } catch {
            Issue.record("Expected client error, got \(error)")
        }
    }

    @Test func execute503ThrowsServerError() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(session: session)

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try await client.execute(request: TestNetworkRequest())
        }
    }

    @Test func injectedResponseValidatorControlsStatusMapping() async {
        struct RejectingValidator: ResponseValidator {
            func validate(_ response: URLResponse, data: Data) throws {
                throw NetworkError.requestFailed("custom validator")
            }
        }

        let session = stubbedSession(statusCode: 200)
        let client = makeClient(session: session, responseValidator: RejectingValidator())

        await #expect(throws: NetworkError.requestFailed("custom validator")) {
            try await client.execute(request: TestNetworkRequest())
        }
    }

    @Test func retry503ExhaustsAttempts() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(
            session: session,
            retryPolicy: .exponential(maxRetries: 3, baseDelay: 0)
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try await client.execute(request: TestNetworkRequest())
        }
        #expect(session.callCount == 4, "1 initial + 3 retries = 4")
    }

    @Test func retry404DoesNotRetry() async {
        let session = stubbedSession(statusCode: 404)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 3, delay: 0)
        )

        await #expect(throws: NetworkError.clientError(
            response: makeTestHTTPErrorResponse(statusCode: 404)
        )) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1, "Client errors should not be retried")
    }

    @Test func retryableTransportFailureRetriesRequests() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.timedOut)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0)
        )

        await #expect(throws: NetworkError.timeout) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 2, "1 initial + 1 retry = 2")
    }

    @Test func noConnectivityTransportFailureRetriesRequests() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.notConnectedToInternet)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0)
        )

        await #expect(throws: NetworkError.noConnectivity) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 2, "1 initial + 1 retry = 2")
    }

    @Test func cancelledTransportFailureThrowsCancellationErrorWithoutRetry() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.cancelled)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 3, delay: 0)
        )

        await #expect(throws: CancellationError.self) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1, "Cancelled requests should not be retried")
    }

    @Test func nsURLCancellationErrorThrowsCancellationErrorWithoutRetry() async {
        let session = MockURLSession()
        session.stubbedError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCancelled
        )
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 3, delay: 0)
        )

        await #expect(throws: CancellationError.self) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1, "Cancelled requests should not be retried")
    }

    @Test func cancelledTaskTransportFailureThrowsCancellationError() async {
        let session = MockURLSession()
        session.stubbedError = URLError(.timedOut)
        session.cancelCurrentTaskBeforeThrowing = true
        let client = makeClient(session: session)
        let task = Task {
            try await client.execute(request: TestNetworkRequest())
        }

        await #expect(throws: CancellationError.self) {
            try await task.value
        }

        #expect(session.callCount == 1)
    }

    @Test func cancellationErrorIsRethrownWithoutRetry() async {
        let session = MockURLSession()
        session.stubbedError = CancellationError()
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 3, delay: 0)
        )

        await #expect(throws: CancellationError.self) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1, "Cancelled requests should not be retried")
    }

    @Test func retryPolicyDoesNotRetryPostByDefault() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0)
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try await client.execute(request: TestNetworkRequest(method: .post))
        }

        #expect(session.callCount == 1)
    }

    @Test func retryPolicyRetriesPostWhenAllowed() async {
        let session = stubbedSession(statusCode: 503)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(
                maxRetries: 1,
                delay: 0,
                retryableMethods: [.post]
            )
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try await client.execute(request: TestNetworkRequest(method: .post))
        }

        #expect(session.callCount == 2)
    }

    @Test func retryPolicyDoesNotRetryUnknownHTTPMethod() async {
        let session = stubbedSession(statusCode: 503)
        let interceptor = MockRequestInterceptor()
        interceptor.methodOverride = "CUSTOM"
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0),
            requestInterceptors: [interceptor]
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1)
    }

    @Test func retryPolicyRetriesCustomHTTPMethodWhenAllowed() async {
        let session = stubbedSession(statusCode: 503)
        let customMethod = HTTPMethod.custom("CUSTOM")
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(
                maxRetries: 1,
                delay: 0,
                retryableMethods: [customMethod]
            )
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try await client.execute(request: TestNetworkRequest(method: customMethod))
        }

        #expect(session.capturedRequests.map(\.httpMethod) == ["CUSTOM", "CUSTOM"])
    }

    @Test func retryVetoedByRetryInterceptorDoesNotRetry() async {
        let session = stubbedSession(statusCode: 503)
        let interceptor = MockRetryInterceptor(decision: .doNotRetry)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 3, delay: 0),
            retryInterceptors: [interceptor]
        )

        await #expect(throws: NetworkError.serverError(
            response: makeTestHTTPErrorResponse(statusCode: 503)
        )) {
            try await client.execute(request: TestNetworkRequest())
        }

        #expect(session.callCount == 1, "Interceptor vetoed — no retries")
        #expect(interceptor.callCount == 1)
    }

    @Test func requestInterceptorRunsForEachRetryAttempt() async {
        let session = stubbedSession(statusCode: 503)
        let store = RetryTokenStore(token: "initial")
        let requestInterceptor = TokenHeaderInterceptor(store: store)
        let retryInterceptor = RefreshTokenRetryInterceptor(store: store)
        let client = makeClient(
            session: session,
            retryPolicy: .fixed(maxRetries: 1, delay: 0),
            requestInterceptors: [requestInterceptor],
            retryInterceptors: [retryInterceptor]
        )

        await #expect(throws: NetworkError.serverError(response: makeTestHTTPErrorResponse(statusCode: 503))) {
            try await client.execute(request: TestNetworkRequest())
        }

        let authorizationHeaders = session.capturedRequests.map {
            $0.value(forHTTPHeaderField: "Authorization")
        }
        #expect(requestInterceptor.interceptCallCount == 2)
        #expect(retryInterceptor.callCount == 1)
        #expect(authorizationHeaders == ["Bearer initial", "Bearer refreshed"])
    }
}
