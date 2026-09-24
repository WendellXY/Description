# Description

Compile-time-validated descriptions for Swift enums, structs, classes, and actors.

```swift
import Description

@Describable
enum RequestState {
    case idle

    @Description("Loading {url}")
    case loading(url: URL)

    @Description("Received {bytes} bytes")
    case loaded(bytes: Int)
}

RequestState.idle.description             // "idle"
RequestState.loaded(bytes: 42).description // "Received 42 bytes"
```

`@Describable` generates an ordinary `CustomStringConvertible` conformance. When the
type explicitly conforms to `Error`, it also generates `LocalizedError`. Placeholders
are checked while the macro expands, so a typo is a compile error with a fix-it, not
a wrong string at runtime.

The whole API is two attributes:

| Attribute | Attach to | Purpose |
| --- | --- | --- |
| `@Describable(_ description: String? = nil, error: String? = nil)` | `enum`, `struct`, `class`, `actor` | Synthesizes the conformances |
| `@Description(_ description: String? = nil, error: String? = nil)` | enum cases | Configures one case |

## Installation

Add the package to `Package.swift`:

```swift
.package(url: "https://github.com/WendellXY/Description.git", from: "0.1.0"),
```

and depend on the `Description` product:

```swift
.target(name: "App", dependencies: [.product(name: "Description", package: "Description")]),
```

Requires Swift 6.0 or later. The package accepts swift-syntax 600 through 604.

## Template syntax

Templates are ordinary string literals with a small placeholder DSL. They don't use
Swift interpolation, because associated values aren't in scope inside an attribute.

| Syntax | Meaning |
| --- | --- |
| `{name}` | A labeled associated value, or a property |
| `{0}`, `{1}` | An associated value by position (enums only) |
| `{{`, `}}` | A literal `{` or `}` |

Escape sequences (`\n`, `\u{2022}`, …) and raw strings (`#"C:\{path}"#`) work as
usual. v1 has no format specifiers (`{value:02X}`), member paths (`{user.name}`),
or arbitrary expressions.

Values are interpolated with Swift's own string interpolation, so any type works,
including generics and optionals, without extra constraints.

## Enums

A case is described by its name unless it has a `@Description`. Associated values
are ignored unless a template refers to them.

```swift
@Describable
enum Comparison {
    case equal

    @Description("Expected {0}, got {1}")
    case mismatch(String, String)
}

Comparison.equal.description               // "equal"
Comparison.mismatch("a", "b").description  // "Expected a, got b"
```

Generated code:

```swift
extension Comparison: CustomStringConvertible {
    var description: String {
        switch self {
        case .equal:
            return "equal"
        case let .mismatch(_0, _1):
            return "Expected \(_0), got \(_1)"
        }
    }
}
```

Cases inside `#if` blocks are mirrored in the generated `switch`.

## Structs, classes, and actors

These types have no natural default, so they require a template. Placeholders
refer to instance properties declared in the type's body.

```swift
@Describable("User(id: {id}, name: {name})")
struct User {
    let id: UUID
    let name: String
}

@Describable("Connection(host: {host}, port: {port})")
final class Connection {
    let host: String
    let port: Int
}

@Describable("Box(value: {value})")
struct Box<T> {
    let value: T
}
```

### Actors

`description` must be synchronous, so the generated members are `nonisolated`.
Placeholders may use `nonisolated` properties and stored `let` constants (the
compiler still requires those to be `Sendable`). Other actor-isolated state is
rejected:

```swift
@Describable("Worker(id: {id})")
actor Worker {
    nonisolated let id: UUID
    var pendingJobs: Int
}

@Describable("Queue(jobs: {jobs})")
// error: '{jobs}' refers to actor-isolated state and cannot be used in a synchronous description
actor Queue {
    var jobs: [Job]
}
```

## Errors

Error support needs no extra macro. If `Error` appears in the annotated type's
inheritance clause, `@Describable` also synthesizes `LocalizedError`, so
`localizedDescription` returns the description:

```swift
@Describable
enum NetworkError: Error {
    @Description("Request failed: {underlying}")
    case requestFailed(underlying: any Error)

    case unavailable
}

NetworkError.unavailable.errorDescription  // "unavailable"
```

When log output and user-facing text should differ, use `error:`:

```swift
@Describable(
    "HTTPError(code: {code}, endpoint: {endpoint})",
    error: "The request failed with HTTP {code}."
)
struct HTTPError: Error {
    let code: Int
    let endpoint: URL
}

String(describing: HTTPError(code: 500, endpoint: url))  // "HTTPError(code: 500, endpoint: …)"
HTTPError(code: 500, endpoint: url).localizedDescription  // "The request failed with HTTP 500."
```

Enum cases work the same way. A case may give only an `error:` template and keep
its name as the description:

```swift
@Describable
enum APIError: Error {
    @Description("invalidStatus(code: {code})", error: "The server returned HTTP {code}.")
    case invalidStatus(code: Int)

    @Description(error: "The request timed out after {0} seconds.")
    case timeout(Int)

    case unavailable
}

APIError.timeout(30).description       // "timeout"
APIError.timeout(30).errorDescription  // "The request timed out after 30 seconds."
```

Without `error:`, `errorDescription` is the same as `description`. Using `error:` on a
type that doesn't conform to `Error` is a compile error, with a fix-it that adds the
conformance.

## Diagnostics

Every mistake is reported during expansion, pointing inside the template where
possible:

| Problem | Diagnostic | Fix-it |
| --- | --- | --- |
| Misspelled field | `unknown description field 'resorce'; available fields: {resource}` | Replace with the closest match |
| Positional index out of range | `description field '{2}' does not exist; case 'value' has 1 associated value` | |
| Unbalanced brace | `unterminated description placeholder; use '{{' for a literal '{'` | Escape the brace |
| Struct/class/actor without a template | `@Describable requires a description template when applied to a struct` | Insert a memberwise template |
| Template on an enum | `@Describable does not accept templates when applied to an enum; …` | Remove the arguments |
| `error:` on a non-error | `'error' is only available for types conforming to Error` | Add `Error` conformance |
| Actor-isolated state | `'{jobs}' refers to actor-isolated state and cannot be used in a synchronous description` | |
| Two `@Description`s on one case | `description is already configured for this declaration` | Remove the duplicate |
| Existing `CustomStringConvertible` / `LocalizedError` | `'Foo' already declares a conformance to 'CustomStringConvertible'; …` | Remove it, or replace `LocalizedError` with `Error` |
| Hand-written `description` / `errorDescription` | `'description' is already implemented; …` | |
| Not a type | `@Describable can only be applied to enum, struct, class, or actor declarations` | |

## Limitations

`@Describable` works on syntax. It doesn't repeat the type checker's semantic lookup,
which keeps it predictable but has consequences:

- **`Error` must be in the declaration's own inheritance clause.** A conformance
  added in an extension (`extension Foo: Error {}`), or through a protocol that
  refines `Error`, isn't detected. Move `Error` onto the declaration.
- **Only properties declared in the type's body are visible.** Superclass members,
  protocol requirements, and properties added in extensions can't be used as
  placeholders.
- **Existing conformances can't be replaced.** A class that already conforms to
  `CustomStringConvertible` through its superclass (for example, any `NSObject`
  subclass, or a subclass of another `@Describable` class) is rejected, because the
  generated `description` can't override the inherited one.
- **Templates must be single-line string literals** (raw strings are fine).
- **Extension macros can't be attached to types declared inside functions.**
