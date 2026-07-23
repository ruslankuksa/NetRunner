import Testing
@testable import NetRunner

extension NetworkClientTests {
    @Test func disabledConnectivityRetryDoesNotCreateDefaultMonitor() {
        let session = MockURLSession()
        var factoryCallCount = 0

        _ = NetworkClient(
            session: session,
            connectivityRetryPolicy: .disabled,
            connectivityMonitorFactory: {
                factoryCallCount += 1
                return TestCancellableConnectivityMonitor()
            }
        )

        #expect(factoryCallCount == 0)
    }

    @Test func enabledConnectivityRetryCreatesDefaultMonitorWhenNotInjected() {
        let session = MockURLSession()
        var factoryCallCount = 0

        _ = NetworkClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
            connectivityMonitorFactory: {
                factoryCallCount += 1
                return TestCancellableConnectivityMonitor()
            }
        )

        #expect(factoryCallCount == 1)
    }

    @Test func ownedConnectivityMonitorIsCancelledOnDeinit() {
        let session = MockURLSession()
        let monitor = TestCancellableConnectivityMonitor()
        var client: NetworkClient? = NetworkClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
            connectivityMonitorFactory: { monitor }
        )

        #expect(client != nil)
        client = nil

        #expect(monitor.cancelCallCount == 1)
    }

    @Test func injectedConnectivityMonitorIsNotCancelledOnDeinit() {
        let session = MockURLSession()
        let monitor = TestCancellableConnectivityMonitor()
        var client: NetworkClient? = NetworkClient(
            session: session,
            connectivityRetryPolicy: .waitUntilConnected(maxRetries: 1, timeout: nil),
            connectivityMonitor: monitor,
            connectivityMonitorFactory: {
                Issue.record("Injected monitor should avoid default factory")
                return TestCancellableConnectivityMonitor()
            }
        )

        #expect(client != nil)
        client = nil

        #expect(monitor.cancelCallCount == 0)
    }
}
