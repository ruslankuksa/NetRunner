import Foundation
import Testing
@testable import NetRunner

@Suite(.timeLimit(.minutes(1)), .tags(.networking))
struct NetworkClientTests {
    func makeClient(
        session: MockURLSession,
        retryPolicy: RetryPolicy = .none,
        requestInterceptors: [any RequestInterceptor] = [],
        retryInterceptors: [any RetryInterceptor] = [],
        responseValidator: any ResponseValidator = DefaultResponseValidator(),
        defaultRequestEncoder: any RequestBodyEncoder = JSONRequestBodyEncoder(),
        defaultResponseDecoder: any ResponseBodyDecoder = JSONResponseBodyDecoder(),
        connectivityRetryPolicy: ConnectivityRetryPolicy = .disabled,
        connectivityMonitor: (any ConnectivityMonitor)? = MockConnectivityMonitor()
    ) -> NetworkClient {
        NetworkClient(
            session: session,
            retryPolicy: retryPolicy,
            requestInterceptors: requestInterceptors,
            retryInterceptors: retryInterceptors,
            responseValidator: responseValidator,
            defaultRequestEncoder: defaultRequestEncoder,
            defaultResponseDecoder: defaultResponseDecoder,
            connectivityRetryPolicy: connectivityRetryPolicy,
            connectivityMonitor: connectivityMonitor
        )
    }

    func stubbedSession(statusCode: Int, data: Data = Data()) -> MockURLSession {
        let session = MockURLSession()
        session.stub(statusCode: statusCode)
        session.stubbedData = data
        return session
    }

    struct FixedRequestBodyEncoder: RequestBodyEncoder {
        let data: Data
        let contentType: String?

        init(text: String, contentType: String? = nil) {
            self.data = Data(text.utf8)
            self.contentType = contentType
        }

        func encode(_ value: any Encodable & Sendable) throws -> Data {
            data
        }
    }

    enum TestCodingError: Error, Sendable {
        case failed
        case unsupportedType
    }

    struct FailingResponseBodyDecoder: ResponseBodyDecoder {
        func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
            throw TestCodingError.failed
        }
    }
}
