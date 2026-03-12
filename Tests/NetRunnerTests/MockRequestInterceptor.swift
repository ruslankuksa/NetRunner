
import Foundation
@testable import NetRunner

final class MockRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    var interceptCallCount = 0
    var headerToAdd: (name: String, value: String)?

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        interceptCallCount += 1
        var modified = request
        if let header = headerToAdd {
            modified.setValue(header.value, forHTTPHeaderField: header.name)
        }
        return modified
    }
}
