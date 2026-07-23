import Foundation
import Testing
@testable import NetRunner

extension NetworkClientTests {
    @Test func execute200DecodesResponse() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":42}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let client = makeClient(session: session)

        let result: Payload = try await client.execute(request: TestNetworkRequest())
        #expect(result.id == 42)
        #expect(session.callCount == 1)
    }

    @Test func executeWithoutResponseBodyCompletes() async throws {
        let session = stubbedSession(statusCode: 204)
        let client = makeClient(session: session)

        try await client.execute(request: TestNetworkRequest())

        #expect(session.callCount == 1)
    }

    @Test func clientDefaultResponseDecoderIsUsedWhenRequestDoesNotOverride() async throws {
        struct Payload: Decodable {
            let createdAt: Date
        }

        let json = #"{"createdAt":"1970-01-01T00:00:00Z"}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let client = makeClient(
            session: session,
            defaultResponseDecoder: JSONResponseBodyDecoder(decoder: decoder)
        )

        let payload: Payload = try await client.execute(request: TestNetworkRequest())

        #expect(payload.createdAt.timeIntervalSince1970 == 0)
    }

    @Test func requestResponseDecoderOverridesClientDefaultResponseDecoder() async throws {
        struct Payload: Decodable {
            let createdAt: Date
        }

        struct ISODateRequest: NetworkRequest {
            let baseURL = URL(string: "https://example.com")!
            let method: HTTPMethod = .get
            let endpoint: any Endpoint = TestEndpoint()

            var options: RequestOptions {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return RequestOptions(responseDecoder: JSONResponseBodyDecoder(decoder: decoder))
            }
        }

        let json = #"{"createdAt":"1970-01-01T00:00:00Z"}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let clientDefaultResponseDecoder = JSONDecoder()
        clientDefaultResponseDecoder.dateDecodingStrategy = .secondsSince1970
        let client = makeClient(
            session: session,
            defaultResponseDecoder: JSONResponseBodyDecoder(decoder: clientDefaultResponseDecoder)
        )

        let payload: Payload = try await client.execute(request: ISODateRequest())

        #expect(payload.createdAt.timeIntervalSince1970 == 0)
    }

    @Test func customResponseDecoderDecodesNonJSONResponse() async throws {
        struct Payload: Decodable, Equatable {
            let value: String
        }

        struct PipeResponseBodyDecoder: ResponseBodyDecoder {
            func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
                guard
                    type == Payload.self,
                    let text = String(data: data, encoding: .utf8),
                    let separatorIndex = text.firstIndex(of: "|")
                else {
                    throw TestCodingError.unsupportedType
                }

                let payload = Payload(value: String(text[text.index(after: separatorIndex)...]))
                guard let typedPayload = payload as? T else {
                    throw TestCodingError.unsupportedType
                }
                return typedPayload
            }
        }

        let session = stubbedSession(statusCode: 200, data: Data("payload|custom".utf8))
        let client = makeClient(session: session, defaultResponseDecoder: PipeResponseBodyDecoder())

        let payload: Payload = try await client.execute(request: TestNetworkRequest())

        #expect(payload == Payload(value: "custom"))
    }

    @Test func clientDefaultRequestEncoderIsUsedWhenBodyDoesNotOverride() async throws {
        struct Payload: Encodable, Sendable {
            let createdAt: Date
        }

        let session = stubbedSession(statusCode: 204)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let client = makeClient(
            session: session,
            defaultRequestEncoder: JSONRequestBodyEncoder(encoder: encoder)
        )

        try await client.execute(
            request: TestNetworkRequestWithBody(body: Payload(createdAt: Date(timeIntervalSince1970: 0)))
        )

        let body = try #require(session.capturedRequests.first?.httpBody)
        let bodyText = try #require(String(data: body, encoding: .utf8))
        #expect(bodyText.contains(#""1970-01-01T00:00:00Z""#))
    }

    @Test func encodedBodyUsesCustomClientDefaultRequestEncoder() async throws {
        struct Payload: Encodable, Sendable {
            let value: Int
        }

        let session = stubbedSession(statusCode: 204)
        let client = makeClient(
            session: session,
            defaultRequestEncoder: FixedRequestBodyEncoder(
                text: "encoded-wire-body",
                contentType: "application/x-netrunner-test"
            )
        )

        try await client.execute(
            request: TestNetworkRequestWithBody(body: Payload(value: 7))
        )

        let request = try #require(session.capturedRequests.first)
        #expect(request.httpBody == Data("encoded-wire-body".utf8))
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-netrunner-test")
    }

    @Test func requestBodyEncoderOverridesClientDefaultRequestEncoder() async throws {
        struct Payload: Encodable, Sendable {
            let createdAt: Date
        }

        struct MillisecondsDateRequest: NetworkRequest {
            let baseURL = URL(string: "https://example.com")!
            let method: HTTPMethod = .post
            let endpoint: any Endpoint = TestEndpoint()
            let payload = Payload(createdAt: Date(timeIntervalSince1970: 1))

            var body: RequestBody? {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .millisecondsSince1970
                return .encoded(payload, encoder: JSONRequestBodyEncoder(encoder: encoder))
            }
        }

        let session = stubbedSession(statusCode: 204)
        let clientDefaultRequestEncoder = JSONEncoder()
        clientDefaultRequestEncoder.dateEncodingStrategy = .iso8601
        let client = makeClient(
            session: session,
            defaultRequestEncoder: JSONRequestBodyEncoder(encoder: clientDefaultRequestEncoder)
        )

        try await client.execute(request: MillisecondsDateRequest())

        let body = try #require(session.capturedRequests.first?.httpBody)
        let bodyText = try #require(String(data: body, encoding: .utf8))
        #expect(bodyText.contains("1000"))
        #expect(bodyText.contains("1970-01-01T00:00:01Z") == false)
    }

    @Test func jsonBodyUsesJSONWhenClientDefaultRequestEncoderIsCustom() async throws {
        struct Payload: Codable, Sendable, Equatable {
            let value: Int
        }

        struct JSONBodyRequest: NetworkRequest {
            let baseURL = URL(string: "https://example.com")!
            let method: HTTPMethod = .post
            let endpoint: any Endpoint = TestEndpoint()
            let payload = Payload(value: 9)

            var body: RequestBody? {
                .json(payload)
            }
        }

        let session = stubbedSession(statusCode: 204)
        let client = makeClient(
            session: session,
            defaultRequestEncoder: FixedRequestBodyEncoder(
                text: "custom-client-default",
                contentType: "application/x-custom"
            )
        )

        try await client.execute(request: JSONBodyRequest())

        let request = try #require(session.capturedRequests.first)
        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder().decode(Payload.self, from: body)
        #expect(decoded == Payload(value: 9))
        #expect(body != Data("custom-client-default".utf8))
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func execute200BadJSONThrowsDecodingFailed() async {
        struct Payload: Decodable { let id: Int }
        let session = stubbedSession(statusCode: 200, data: "not json".data(using: .utf8)!)
        let client = makeClient(session: session)

        do {
            let _: Payload = try await client.execute(request: TestNetworkRequest())
            Issue.record("Expected invalid JSON to throw decodingFailed")
        } catch NetworkError.decodingFailed {
            // Expected.
        } catch {
            Issue.record("Expected decodingFailed, got \(error)")
        }
    }

    @Test func customResponseDecoderErrorsAreWrappedAsDecodingFailed() async {
        struct Payload: Decodable {
            let id: Int
        }

        let session = stubbedSession(statusCode: 200, data: Data("custom".utf8))
        let client = makeClient(session: session, defaultResponseDecoder: FailingResponseBodyDecoder())

        do {
            let _: Payload = try await client.execute(request: TestNetworkRequest())
            Issue.record("Expected custom decoder error to be wrapped")
        } catch NetworkError.decodingFailed(let error) {
            #expect(error is TestCodingError)
        } catch {
            Issue.record("Expected decodingFailed, got \(error)")
        }
    }
}
