@testable import NetRunner

struct TestEndpoint: Endpoint {
    var path: RequestPath

    init(_ path: String = "/test") {
        self.path = RequestPath(path)
    }
}
