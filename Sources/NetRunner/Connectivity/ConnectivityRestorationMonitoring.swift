import Foundation

protocol ConnectivityRestorationMonitoring: ConnectivityMonitor {
    func waitForConnectivityRestoration(timeout: TimeInterval?) async throws
}
