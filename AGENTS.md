# Repository Guidelines

## Project Structure & Module Organization

NetRunner is a zero-dependency Swift Package Manager library. The package manifest is `Package.swift`, public source lives in `Sources/NetRunner`, and tests live in `Tests/NetRunnerTests`. Shared test doubles and fixtures are kept beside the tests, with request fixtures in `Tests/NetRunnerTests/Fixtures`. `README.md` is the user-facing package documentation; keep it in sync when public APIs or examples change. `CLAUDE.md` contains existing agent-oriented notes and should remain consistent with this guide.

## Build, Test, and Development Commands

- `swift build`: compile the package on the host platform.
- `swift test`: run the full Swift Testing suite.
- `swift test --filter NetRunnerTests/<TestMethodName>`: run one focused test while iterating.
- `swift package describe`: inspect package targets, products, and platform settings.

## Coding Style & Naming Conventions

Use Swift 5 language mode under Swift tools 6.0. Follow the existing style: four-space indentation, opening braces on the declaration line, `UpperCamelCase` for types and protocols, and `lowerCamelCase` for methods, properties, enum cases, and test functions. Favor protocol-oriented APIs with default implementations in extensions, matching the current `NetRunner`, `NetworkRequest`, and `Endpoint` design. Keep public API names aligned with the Swift API Design Guidelines, and add concise `///` documentation for public protocols, methods, and types. There is no formatter configuration in this repository, so match nearby code.

## Testing Guidelines

Tests use Swift Testing (`import Testing`) with `@Test`, optional `@Suite`, and `#expect`. Name tests by behavior, for example `execute401ThrowsUnauthorized` or `cachePolicyIsPropagated`. Add or update tests for URL construction, status-code mapping, retry behavior, interceptors, request body rules, and any public API change. Keep network behavior mocked through `MockURLSession`; tests should not call real services. No coverage threshold is defined, but new behavior should be covered before merging.

## Commit & Pull Request Guidelines

Recent commits use short, descriptive subjects such as `Add Sendable conformances...`, `Update README...`, and `Align public API...`. Prefer imperative, present-tense subjects under about 72 characters, with details in the body when needed. Pull requests should include a concise description, any API or platform impact, linked issues if applicable, and the exact validation run, usually `swift test`. Update `README.md` for user-visible API changes.

## Security & Configuration Tips

Do not commit credentials, bearer tokens, or live service URLs. Use examples and mocks for authentication, retry, and interceptor behavior.
