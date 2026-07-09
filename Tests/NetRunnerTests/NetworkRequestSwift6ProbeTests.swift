import Foundation
import Testing

struct NetworkRequestSwift6ProbeTests {

    @Test func swift6ConsumerCanCaptureNetworkRequestInSendableRetryClosure() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let probeRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("NetRunnerSwift6Probe-\(UUID().uuidString)")
        let sourcesRoot = probeRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("Probe")
        let moduleCachePath = probeRoot.appendingPathComponent("ModuleCache")

        try FileManager.default.createDirectory(
            at: sourcesRoot,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: moduleCachePath,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: probeRoot)
        }

        try makeProbePackage(pathDependency: packageRoot.path)
            .write(
                to: probeRoot.appendingPathComponent("Package.swift"),
                atomically: true,
                encoding: .utf8
            )
        try makeProbeSource()
            .write(
                to: sourcesRoot.appendingPathComponent("main.swift"),
                atomically: true,
                encoding: .utf8
            )

        let output = try runSwiftBuild(
            packagePath: probeRoot,
            moduleCachePath: moduleCachePath
        )

        #expect(output.exitCode == 0, Comment(rawValue: output.text))
    }

    private func makeProbePackage(pathDependency: String) -> String {
        """
        // swift-tools-version: 6.0

        import PackageDescription

        let package = Package(
            name: "NetRunnerSwift6Probe",
            platforms: [
                .macOS(.v11)
            ],
            dependencies: [
                .package(path: "\(pathDependency)")
            ],
            targets: [
                .executableTarget(
                    name: "Probe",
                    dependencies: [
                        "NetRunner"
                    ],
                    swiftSettings: [
                        .swiftLanguageMode(.v6)
                    ]
                )
            ]
        )

        """
    }

    private func makeProbeSource() -> String {
        """
        import Foundation
        import NetRunner

        private struct ProbeEndpoint: Endpoint {
            let path: RequestPath = "/probe"
        }

        private struct BodylessRequest: NetworkRequest {
            let baseURL = URL(string: "https://example.com")!
            let method: HTTPMethod = .get
            let endpoint: any Endpoint = ProbeEndpoint()
        }

        private struct Payload: Encodable, Sendable {
            let id: Int
        }

        private struct BodyRequest: NetworkRequest {
            let baseURL = URL(string: "https://example.com")!
            let method: HTTPMethod = .post
            let endpoint: any Endpoint = ProbeEndpoint()
            private let payload = Payload(id: 1)

            var body: RequestBody? {
                .json(payload)
            }
        }

        private func execute(request: any NetworkRequest) async throws -> Int {
            _ = try request.makeURLRequest()
            return 1
        }

        private func recover<T: Sendable>(
            request: any NetworkRequest,
            retry: @escaping @Sendable () async throws -> T
        ) async throws -> T {
            try await retry()
        }

        private func call(request: any NetworkRequest) async throws -> Int {
            try await recover(request: request) {
                try await execute(request: request)
            }
        }

        @main
        private struct Main {
            static func main() async throws {
                _ = try BodylessRequest().makeURLRequest()
                _ = try BodyRequest().makeURLRequest()
                _ = try await call(request: BodylessRequest())
            }
        }

        """
    }

    private func runSwiftBuild(
        packagePath: URL,
        moduleCachePath: URL
    ) throws -> (exitCode: Int32, text: String) {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift",
            "build",
            "--package-path",
            packagePath.path
        ]
        process.standardOutput = output
        process.standardError = output
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["CLANG_MODULE_CACHE_PATH": moduleCachePath.path]
        ) { _, new in new }

        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, text)
    }
}
