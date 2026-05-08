// MARK: - Thread Safety
// @unchecked Sendable is safe here because tests configure and assert these
// doubles around awaited client calls, and NetRunner invokes them sequentially
// inside a single request or upload operation.
final class RetryTokenStore: @unchecked Sendable {
    var token: String

    init(token: String) {
        self.token = token
    }
}
