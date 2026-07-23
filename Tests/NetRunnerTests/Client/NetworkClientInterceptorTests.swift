import Foundation
import Testing
@testable import NetRunner

extension NetworkClientTests {
    @Test func requestInterceptorIsAppliedBeforeRequest() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)

        let interceptor = MockRequestInterceptor()
        interceptor.headerToAdd = (name: "X-Token", value: "abc")
        let client = makeClient(
            session: session,
            requestInterceptors: [interceptor]
        )

        let _: Payload = try await client.execute(request: TestNetworkRequest())

        #expect(interceptor.interceptCallCount == 1)
        #expect(
            session.capturedRequests.first?
                .value(forHTTPHeaderField: "X-Token") == "abc"
        )
    }

    @Test func requestInterceptorsAppliedInOrder() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)

        let first = MockRequestInterceptor()
        first.headerToAdd = (name: "X-First", value: "1")
        let second = MockRequestInterceptor()
        second.headerToAdd = (name: "X-Second", value: "2")

        let client = makeClient(
            session: session,
            requestInterceptors: [first, second]
        )
        let _: Payload = try await client.execute(request: TestNetworkRequest())

        let captured = session.capturedRequests.first
        #expect(captured?.value(forHTTPHeaderField: "X-First") == "1")
        #expect(captured?.value(forHTTPHeaderField: "X-Second") == "2")
    }

    @Test func cachePolicyForwardedToURLRequest() async throws {
        struct Payload: Decodable { let id: Int }
        let json = #"{"id":1}"#.data(using: .utf8)!
        let session = stubbedSession(statusCode: 200, data: json)
        let client = makeClient(session: session)

        let request = TestNetworkRequest(cachePolicy: .returnCacheDataElseLoad)
        let _: Payload = try await client.execute(request: request)

        #expect(
            session.capturedRequests.first?.cachePolicy
                == .returnCacheDataElseLoad
        )
    }
}
