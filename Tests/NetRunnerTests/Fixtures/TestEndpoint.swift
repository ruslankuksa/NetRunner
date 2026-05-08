@testable import NetRunner

struct TestEndpoint: Endpoint {
    var path: String

    init(_ path: String = "/test") {
        self.path = path
    }
}
