# Contributing

Thanks for improving NetRunner.

## Development

NetRunner is a zero-dependency Swift Package Manager library for Apple
platforms.

Use these commands before opening a pull request:

```bash
swift build
swift test
```

Tests use Swift Testing. Prefer `@Test`, `#expect`, and `#require`; do not add
XCTest assertions to unit tests.

### Test organization

Keep tests in the domain folders under `Tests/NetRunnerTests`:
`Client`, `Compatibility`, `Connectivity`, `Core`, `Request`, `Retry`,
`Upload`, and `Validation`. Shared request fixtures belong in `Fixtures`,
reusable mocks and interceptors in `TestDoubles`, and cross-suite test support
in `Support`.

Large suites may use one shared `@Suite` declaration and focused extensions in
separate files. Apply these tags when they describe the work a suite performs:

- `.networking` for client or upload request execution.
- `.connectivity` for connectivity state and monitor behavior.
- `.filesystem` for temporary-file behavior.
- `.compatibility` for consumer-compatibility probes.
- `.slow` for deliberately expensive tests such as subprocess builds.

Suites that await asynchronous work should have an explicit time limit. Keep
tests isolated from live services by using `MockURLSession` and the existing
connectivity test doubles.

### Test assertions and concurrency

Assert the exact error case whenever the contract makes it knowable. Use
`#require` before indexing optional or collection state, and write boolean
comparisons such as `value == false` so failures show the evaluated value.

Async cancellation tests must wait for an observable registration or start
condition before cancelling. Do not use a fixed sleep or a single
`Task.yield()` as a synchronization mechanism. After cancellation, assert any
relevant cleanup state, such as a pending waiter count returning to zero.

## Pull Requests

Pull requests should include:

- A concise description of the behavior change.
- Any public interface, source compatibility, or platform impact.
- Tests for new behavior or bug fixes.
- The exact validation commands run.

Keep user-facing documentation in `README.md` in sync with public interface
changes.

## Public Interface Changes

NetRunner follows semantic versioning. Avoid source-breaking changes in patch
and minor releases. When a breaking change is necessary, call it out clearly in
the pull request and changelog.

## Release Checklist

Before publishing a tag, run:

```bash
swift build
swift test
git describe --tags --dirty
```

Publish only when `git describe --tags --dirty` does not end in `-dirty`.

## Security

Do not commit credentials, bearer tokens, or live service URLs. Use examples,
mocks, and local fixtures for authentication, retry, upload, and interceptor
behavior.
