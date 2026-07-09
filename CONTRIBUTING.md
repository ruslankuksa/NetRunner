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
