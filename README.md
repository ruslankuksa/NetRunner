# NetRunner

A zero-dependency Swift networking library built on protocol-oriented design. All public types are protocols with default implementations — consumers adopt them by conforming, not by subclassing or instantiating concrete types.

## Requirements

| Platform | Minimum |
|----------|---------|
| iOS | 13.4 |
| macOS | 11.0 |
| tvOS | 13.4 |
| watchOS | 7.0 |

## Installation

Add the package via Swift Package Manager:

```swift
.package(url: "https://github.com/yourname/NetRunner", from: "1.0.0")
```

Then add `"NetRunner"` to your target's dependencies.

---

## Quick start

### 1. Define an endpoint

```swift
enum UserEndpoint: Endpoint {
    case profile(id: String)
    case list

    var path: String {
        switch self {
        case .profile(let id): return "/users/\(id)"
        case .list:            return "/users"
        }
    }
}
```

### 2. Define a request

```swift
struct GetUserRequest: NetworkRequest {
    var baseURL: URL { URL(string: "https://api.example.com")! }
    var method: HTTPMethod { .get }
    var endpoint: any Endpoint
    var headers: HTTPHeaders? = ["Accept": "application/json"]
    var parameters: QueryParameters? = nil
    var httpBody: Encodable? = nil

    init(id: String) {
        endpoint = UserEndpoint.profile(id: id)
    }
}
```

### 3. Create a client and execute

```swift
// Simple — using NetworkClient
let client = NetworkClient()

let user: User = try await client.execute(request: GetUserRequest(id: "42"))
```

Or conform your own type to `NetRunner` (iOS 13.4+):

```swift
struct APIClient: NetRunner {}

let user: User = try await APIClient().execute(request: GetUserRequest(id: "42"))
```

---

## NetworkClient

`NetworkClient` is a Swift actor that assembles all library features in one place.

```swift
public actor NetworkClient: NetRunner {
    public init(
        session: any URLSessionProtocol = URLSession.shared,
        retryPolicy: RetryPolicy = .none,
        requestInterceptors: [any RequestInterceptor] = [],
        responseInterceptors: [any ResponseInterceptor] = [],
        connectivityRetryPolicy: ConnectivityRetryPolicy = .disabled,
        connectivityMonitor: (any ConnectivityMonitor)? = nil
    )
}
```

### Retry

```swift
// Retry up to 3 times with exponential back-off starting at 1 second
let client = NetworkClient(
    retryPolicy: .exponential(maxAttempts: 3, baseDelay: 1.0)
)

// Retry up to 5 times with a fixed 2-second delay
let client = NetworkClient(
    retryPolicy: .fixed(maxAttempts: 5, delay: 2.0)
)
```

Retry is only attempted for transient errors: `.timeout`, `.noConnectivity`, `.serverError`. Client errors (4xx) and decode errors are never retried. Transport failures from `URLSession`, such as `URLError(.timedOut)` and `URLError(.notConnectedToInternet)`, are mapped to `NetworkError` before retry decisions.

Automatic retries default to idempotent HTTP methods: `.get`, `.put`, and `.delete`. If a request is safe to replay for your backend, opt in explicitly. If a request interceptor changes the `URLRequest` to an HTTP method NetRunner cannot map to `HTTPMethod`, the attempt is treated as non-retryable.

```swift
let client = NetworkClient(
    retryPolicy: .fixed(
        maxAttempts: 1,
        delay: 0,
        retryableMethods: [.post]
    )
)
```

### No-connectivity retry

Opt in to waiting for connectivity before retrying requests that fail with `.noConnectivity`:

```swift
let client = NetworkClient(
    connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: 60)
)
```

When a request fails because the connection is unavailable, `NetworkClient` waits for `ConnectivityMonitor` to report connectivity, then retries the same request inside the original async call. The caller can still cancel the task. The timeout is applied to each connectivity wait attempt. If connectivity is not restored before the timeout, the request throws `NetworkError.noConnectivity`. If the connectivity retry budget is exhausted, normal `RetryPolicy` handling can still retry `.noConnectivity`.

Connectivity retry uses the same method-safety default as `RetryPolicy`: `.get`, `.put`, and `.delete`. For non-idempotent methods, opt in only when the endpoint is safe to replay:

```swift
let client = NetworkClient(
    connectivityRetryPolicy: .waitUntilConnected(
        maxAttempts: 1,
        timeout: 60,
        retryableMethods: [.post]
    )
)
```

This does not replay old requests in the background after the original call has failed.

Custom `ConnectivityMonitor` implementations can implement `waitForConnectivityRestoration(timeout:)` when they need to wait for a future connected signal after a failed request. The default implementation delegates to `waitUntilConnected(timeout:)`.

### Connectivity state

Use `NetworkPathConnectivityMonitor` directly when the app needs to present offline UI without adding no-connectivity handling to every request:

```swift
let connectivityMonitor = NetworkPathConnectivityMonitor()

let client = NetworkClient(
    connectivityRetryPolicy: .waitUntilConnected(maxAttempts: 1, timeout: 60),
    connectivityMonitor: connectivityMonitor
)

let observationTask = Task { @MainActor in
    for await state in connectivityMonitor.connectivityStates() {
        isOfflineBannerVisible = state == .disconnected
    }
}
```

The connectivity state stream is intended for app-level observation, such as an offline banner in a root view model. NetRunner provides the state stream and retry infrastructure; the app decides how to present offline UI. Prefer SwiftUI `.task {}` or cancel manually-created observation tasks when the owner is dismissed or deinitialized. `NWPath.Status.satisfied` is emitted as `.connected`; all other path statuses are emitted as `.disconnected`. Requests still throw `NetworkError.noConnectivity` when connectivity retry is disabled, times out, retry policy is exhausted, the request method is not retryable, or the request task is cancelled.

### Request interceptors

Mutate the `URLRequest` before it is sent — add auth headers, sign requests, etc.

```swift
struct BearerTokenInterceptor: RequestInterceptor {
    let token: String

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var r = request
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return r
    }
}

let client = NetworkClient(
    requestInterceptors: [BearerTokenInterceptor(token: myToken)]
)
```

Multiple interceptors are applied left-to-right before each attempt, including retry attempts. This lets interceptors read refreshed credentials or regenerate per-attempt signatures.

### File uploads

`NetworkClient` and custom `NetRunner` conformers support raw data, raw file, and `multipart/form-data` uploads with progress events. On iOS 15 / macOS 12 / tvOS 15 / watchOS 8 and newer, progress comes from `URLSessionTaskDelegate`; on older supported OS versions, `URLSession` only provides a completion progress event.

```swift
struct AvatarUpload: UploadRequest {
    var baseURL: URL { URL(string: "https://api.example.com")! }
    var method: HTTPMethod { .post }
    var endpoint: any Endpoint
    var headers: HTTPHeaders? = ["Accept": "application/json"]
    var parameters: QueryParameters? = nil
    var uploadBody: UploadBody

    init(endpoint: any Endpoint = UserEndpoint.profile(id: "42"), uploadBody: UploadBody) {
        self.endpoint = endpoint
        self.uploadBody = uploadBody
    }
}

let request = AvatarUpload(
    uploadBody: .multipart(
        fields: ["displayName": "Blob"],
        files: [
            MultipartFile(
                fieldName: "avatar",
                fileURL: avatarURL,
                fileName: "avatar.jpg",
                contentType: "image/jpeg"
            )
        ],
        boundary: nil
    )
)

for try await event in client.upload(request: request, responseType: User.self) {
    switch event {
    case .progress(let progress):
        print(progress.fractionCompleted)
    case .response(let user):
        print(user)
    }
}
```

For APIs that expect the complete request body directly, use `.data(data:contentType:)` for in-memory bytes or `.rawFile(fileURL:contentType:)` for a local file. Uploads with no response body can call `client.upload(request:)`, which emits `UploadEvent<Void>`. Multipart uploads are prepared once before the first attempt; retries reuse the same temporary file, and NetRunner removes it when the upload finishes or fails.

Custom `NetRunner` conformers get default upload implementations backed by `URLSession.shared`. Use `NetworkClient` when uploads need injected sessions, retry policies, or request/response interceptors.

### Response interceptors

Veto a retry after a failure — useful for token-refresh logic or circuit breakers.

```swift
struct TokenRefreshInterceptor: ResponseInterceptor {
    func shouldRetry(context: RetryContext) async -> Bool {
        guard context.error == .unauthorized else { return true }
        return await refreshToken()
    }
}
```

All response interceptors must approve (unanimity) for a retry to proceed.

### Caching

Configure the storage capacity on the `URLSession`, then set the policy per request.

```swift
let config = URLSessionConfiguration.default
config.urlCache = URLCache(
    memoryCapacity: 10 * 1024 * 1024,   // 10 MB RAM
    diskCapacity:   100 * 1024 * 1024   // 100 MB disk
)
let client = NetworkClient(session: URLSession(configuration: config))
```

Per-request cache policy via `NetworkRequest`:

```swift
struct CatalogRequest: NetworkRequest {
    // Return stale cache rather than failing when offline
    var cachePolicy: URLRequest.CachePolicy { .returnCacheDataElseLoad }
    ...
}
```

| Policy | Behaviour |
|--------|-----------|
| `.useProtocolCachePolicy` | Follows server `Cache-Control` / `ETag` headers (default) |
| `.reloadIgnoringLocalCacheData` | Always hits network; still writes to cache |
| `.returnCacheDataElseLoad` | Returns cached data regardless of freshness; hits network only on cache miss |
| `.returnCacheDataDontLoad` | Returns cached data or fails — never hits network |
| `.reloadRevalidatingCacheData` | Always sends conditional request; returns cached body on 304 |

---

## Error handling

```swift
do {
    let user: User = try await client.execute(request: GetUserRequest(id: "42"))
} catch NetworkError.unauthorized {
    // 401
} catch NetworkError.clientError(let statusCode) {
    // 400–499 (except 401)
} catch NetworkError.serverError(let statusCode) {
    // 500–599
} catch NetworkError.timeout {
    // URLError.timedOut
} catch NetworkError.noConnectivity {
    // no internet / connection lost
} catch NetworkError.decodingFailed(let error) {
    // JSON decode failure
}
```

### `NetworkError` reference

| Case | Description |
|------|-------------|
| `.invalidURL` | The URL string could not be parsed |
| `.requestFailed(String)` | Unhandled HTTP status or URL error |
| `.invalidResponse` | Response was not an `HTTPURLResponse` |
| `.decodingFailed(Error)` | JSON decoding failed |
| `.httpBodyNotAllowedForGET` | `httpBody` set on a GET request |
| `.uploadBodyNotAllowedForGET` | Upload body set on a GET request |
| `.unauthorized` | HTTP 401 |
| `.clientError(statusCode:)` | HTTP 400–499 (except 401) |
| `.serverError(statusCode:)` | HTTP 500–599 |
| `.timeout` | Request timed out |
| `.noConnectivity` | No internet connection |

---

## Array encoding

Control how array query parameters are serialised:

```swift
struct SearchRequest: NetworkRequest {
    var parameters: QueryParameters? = ["ids": [1, 2, 3]]
    var arrayEncoding: ArrayEncoding { .brackets }   // ids[]=1&ids[]=2&ids[]=3
    // .noBrackets  →  ids=1&ids=2&ids=3
    // .commaSeparated  →  ids=1,2,3
}
```

Default is `.brackets`.

---

## Testability

`NetworkClient` accepts any `URLSessionProtocol` — swap in a mock during tests:

```swift
let mock = MockURLSession()
mock.stub(statusCode: 200, data: jsonData)

let client = NetworkClient(session: mock)
let result: User = try await client.execute(request: GetUserRequest(id: "1"))
XCTAssertEqual(mock.callCount, 1)
```
