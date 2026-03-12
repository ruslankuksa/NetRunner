
import Foundation
@testable import NetRunner

// MARK: - Thread Safety
// @unchecked Sendable is safe here because:
// 1. Each test creates its own instance (no cross-test sharing)
// 2. Configuration happens before the actor call (sequential)
// 3. Assertions happen after `await` returns (happens-before barrier)
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
