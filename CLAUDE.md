# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build the package
swift build

# Run all tests
swift test

# Run a single test
swift test --filter NetRunnerTests/<TestMethodName>
```

## Architecture

NetRunner is a zero-dependency Swift Package Manager networking library built entirely on protocol-oriented design. All public types are protocols with default implementations via protocol extensions, so consumers adopt them by conforming — not by subclassing or instantiating concrete types.

### Core flow

1. A consumer defines a type conforming to `NetworkRequest`, which describes one HTTP request (`baseURL: URL` + `Endpoint` path, method, headers, query parameters, optional `httpBody: Encodable`).
2. A service/client type conforms to `NetRunner` and calls `execute(request:)` or `send(request:)`. The default implementation in the `NetRunner` extension builds the `URLRequest` via `NetworkRequest.makeURLRequest()`, calls `URLSession.shared`, validates the response through `validate(_:)`, and decodes via `JSONDecoder`.
3. `validate(_:)` is part of the `NetRunner` protocol (not just the extension), so consumers can override it — the primary use case is custom auth error handling (e.g., token refresh on 401).

### Key protocols and types

| Type | Role |
|------|------|
| `NetRunner` | Adopted by network service/client types; provides `execute` and `send` default impls |
| `NetworkRequest` | Describes a single HTTP request; `makeURLRequest()` builds the `URLRequest` |
| `Endpoint` | Single `path: String` property; composed into `NetworkRequest` |
| `HTTPMethod` | `.get`, `.post`, `.put`, `.patch`, `.delete` |
| `ArrayEncoding` | How array query params are serialized: `.brackets`, `.noBrackets`, `.commaSeparated` |
| `NetworkError` | `LocalizedError` covering: `invalidURL`, `requestFailed(String)`, `invalidResponse`, `decodingFailed(Error)`, `httpBodyNotAllowedForGET`, `unauthorized`, `timeout`, `noConnectivity`, `serverError(statusCode:)`, `clientError(statusCode:)` |
| `RequestInterceptor` | Intercepts outgoing requests via `intercept(_:)` |
| `ResponseInterceptor` | Decides whether to retry via `shouldRetry(context:)` |
| `RetryPolicy` | `.none`, `.fixed(maxAttempts:delay:)`, `.exponential(maxAttempts:baseDelay:)` |

### Important constraints

- Setting `httpBody` on a `.get` request throws `NetworkError.httpBodyNotAllowedForGET`.
- `decoder`, `encoder`, and `arrayEncoding` have default implementations on `NetworkRequest` (default array encoding is `.brackets`).
- Platform minimums: iOS 13, macOS 11, tvOS 13, watchOS 7.
