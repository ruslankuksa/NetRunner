# Changelog

All notable changes to NetRunner are documented in this file.

NetRunner follows semantic versioning. Breaking public interface changes are
released under a new major version.

## Unreleased

- Added MIT licensing, contribution guidance, security reporting guidance, and
  macOS CI for `swift build` and `swift test`.
- Added `RequestPath` for path-only endpoint construction with centralized
  slash normalization and base URL path preservation.
- Replaced untyped query parameter values with typed `QueryValue` support for
  strings, integers, doubles, booleans, and arrays.
- Made `NetworkClient` the primary execution path and removed public default
  execution pipelines from `NetRunner`.
- Replaced response retry hooks with `RetryInterceptor` and `RetryDecision`.
- Added injectable `ResponseValidator` support.
- Reworked upload preparation so multipart content headers are finalized after
  request interceptors.
- Replaced retry policy enum cases with validated factories using
  `maxRetries`.
- Opened `HTTPMethod` to custom methods.
- Added default `headers` and `parameters` request implementations plus
  client-level request body encoder and response body decoder defaults.
- Added protocol-based `RequestBodyEncoder` and `ResponseBodyDecoder` adapters,
  with JSON defaults and per-request overrides through `RequestBody` and
  `RequestOptions`.

## 3.5.0

- Made `NetworkRequest` `Sendable`.
- Changed request bodies to require `Encodable & Sendable`.
- Added default bodyless request behavior so requests without bodies can omit
  `httpBody`.
- Added a Swift 6 consumer probe test for `NetworkRequest` capture inside
  `@Sendable` closures.

## 3.0.0

- Documented Swift Package Manager installation.
- Aligned the public interface for Swift 6 concurrency compatibility.

## 2.2.0

- Renamed request execution APIs from `send` to `execute`.
