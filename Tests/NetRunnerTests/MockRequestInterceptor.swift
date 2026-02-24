
import Foundation
@testable import NetRunner

final class MockRequestInterceptor: RequestInterceptor, @unchecked Sendable {
    var adaptCallCount = 0
    var headerToAdd: (name: String, value: String)?

    func adapt(_ request: URLRequest) async throws -> URLRequest {
        adaptCallCount += 1
        var modified = request
        if let header = headerToAdd {
            modified.setValue(header.value, forHTTPHeaderField: header.name)
        }
        return modified
    }
}
