# Description

[![CI](https://github.com/WendellXY/Description/actions/workflows/ci.yml/badge.svg)](https://github.com/WendellXY/Description/actions/workflows/ci.yml)

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

`@Describable` turns synthesis on; `@Description` supplies the text. The macro
generates ordinary conformances: `CustomStringConvertible` by default, plus
`LocalizedError` when the type explicitly conforms to `Error`, and on request
`CustomDebugStringConvertible` or properties of your own. Placeholders are checked
while the macro expands, so a typo is a compile error with a fix-it rather than a
wrong string at runtime.

| Attribute | Attach to | Purpose |
| --- | --- | --- |
| `@Describable(generating:default:)` | `enum`, `struct`, `class`, `actor` | Enables synthesis |
| `@DescribableProperties` | a `@Describable` type | Generates custom properties |
| `@Description("…")` | the type, or enum cases | The main text (`description`) |
| `@Description(target, "…")` | the type, or enum cases | Text for `.error`, `.debug`, or a custom property |
| `@Description(raw: #"…"#)`, `@Description(target, raw: #"…"#)` | the type, or enum cases | Text with arbitrary Swift expressions |

## Installation

Add the package to `Package.swift`:

```swift
.package(url: "https://github.com/WendellXY/Description.git", from: "0.3.0"),
```

and depend on the `Description` product:

```swift
.target(name: "App", dependencies: [.product(name: "Description", package: "Description")]),
```

Requires Swift 6.0 or later. The package accepts swift-syntax 600 through 604.

## Templates

Templates are string literals with a small placeholder language. They don't use
Swift interpolation, because associated values aren't in scope inside an attribute.

| Syntax | Meaning |
| --- | --- |
| `{name}` | A labeled associated value, or a property declared in the type's body |
| `{0}`, `{1}` | An associated value by position (enums only) |
| `{info.redPacketId}` | A member path |
| `{notify?.uid}` | Optional chaining |
| `{notify?.uid ?? 0}` | A literal default: integer, float, string, `true`, `false`, or `nil` |
| `{state.resumeData?}` | Presence: `true` when the value isn't `nil` |
| `{{`, `}}` | A literal `{` or `}` |

The macro validates the first name of every placeholder, including a spelling fix-it
and actor-isolation checks. Member names after it are checked by the compiler.
Escape sequences (`\n`, `\u{2022}`, …) and raw strings work as usual; a raw string
avoids escaping string defaults:

```swift
@Description(#"webGame(gameId: {config.gameId ?? "nil"}, hasResumeData: {state.resumeGameData?})"#)
case webGame(config: GameConfig, state: GameState)
```

Values are interpolated with Swift's own string interpolation, so any type works,
including generics and optionals, without extra constraints.

### Raw templates

When a placeholder needs more than a path, such as a call, an operator, or a closure, use
`raw:`. Each `{…}` then holds any Swift expression, copied into the generated code:

```swift
@Description(raw: #"cart(items: {items.filter { $0.isActive }.count}, total: {total.formatted()})"#)
case cart(items: [Item], total: Decimal)

@Description(.error, raw: #"{String(localized: "game_info_lost", bundle: .module)}"#)
case gameInfoLost
```

Expressions can use the type's members and, in enum cases, associated values by
label, or `_0`, `_1`, … when unlabeled. The macro checks that each expression
parses; everything else is up to the compiler.

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

Cases inside `#if` blocks are mirrored in the generated `switch`. A `@Description`
on the enum itself is the text for every case that has none of its own, and can
use properties declared in the enum's body.

### Raw values and other defaults

`default:` chooses the text of cases without a `@Description`:

```swift
@Describable(default: .rawValue)
enum PayErrorCode: Int, Error {
    case timeout = 1016          // "1016"
    @Description("cancelled")
    case cancelled = 1           // "cancelled"
}

@Describable(default: .member("title"))
enum Tab {
    case chat, home
    var title: String { ... }
}
```

## Structs, classes, and actors

These types have no case names, so they need a `@Description` (or a
`default: .member(…)`). Placeholders refer to properties declared in the type's body.

```swift
@Describable
@Description("User(id: {id}, name: {name})")
struct User {
    let id: UUID
    let name: String
}

@Describable
@Description("Connection(host: {host}, port: {port})")
final class Connection {
    let host: String
    let port: Int
}

@Describable
@Description("Box(value: {value})")
struct Box<T> {
    let value: T
}
```

### Actors

The generated members are `nonisolated`, because the protocol requirements are
synchronous. Placeholders may use `nonisolated` properties and stored `let`
constants (the compiler still requires those to be `Sendable`). Other
actor-isolated state is rejected:

```swift
@Describable
@Description("Worker(id: {id})")
actor Worker {
    nonisolated let id: UUID
    var pendingJobs: Int
}

@Describable
@Description("Queue(jobs: {jobs})")
// error: '{jobs}' refers to actor-isolated state and cannot be used in a synchronous description
actor Queue {
    var jobs: [Job]
}
```

## Targets: errors, debug descriptions, and your own properties

`@Description(target, "…")` sets the text of one generated property. A target
without its own text uses the main text.

| Target | Generates |
| --- | --- |
| `.description` (the default) | `description`, `CustomStringConvertible` |
| `.error` | `errorDescription`, `LocalizedError` |
| `.debug` | `debugDescription`, `CustomDebugStringConvertible` |
| `"name"` or `.property("name")` | `var name: String` |

### Errors

If `Error` appears in the type's inheritance clause, `@Describable` also synthesizes
`LocalizedError`, so `localizedDescription` returns the error text:

```swift
@Describable
@Description("HTTPError(code: {code}, endpoint: {endpoint})")
@Description(.error, "The request failed with HTTP {code}.")
struct HTTPError: Error {
    let code: Int
    let endpoint: URL
}

String(describing: HTTPError(code: 500, endpoint: url))  // "HTTPError(code: 500, endpoint: …)"
HTTPError(code: 500, endpoint: url).localizedDescription  // "The request failed with HTTP 500."

@Describable
enum APIError: Error {
    @Description("invalidStatus(code: {code})")
    @Description(.error, "The server returned HTTP {code}.")
    case invalidStatus(code: Int)

    @Description(.error, "The request timed out after {0} seconds.")
    case timeout(Int)

    case unavailable
}

APIError.timeout(30).description       // "timeout"
APIError.timeout(30).errorDescription  // "The request timed out after 30 seconds."
APIError.unavailable.errorDescription  // "unavailable"
```

Using `.error` on a type that doesn't conform to `Error` is a compile error, with a
fix-it that adds the conformance.

### Debug descriptions

A `.debug` template adds `CustomDebugStringConvertible`. To generate *only* the
debug description, list the targets explicitly:

```swift
@Describable(generating: [.debug])
enum TabIndex: Int {
    @Description(.debug, "Main.MainTabBar.Tab.Chat") case chat
    @Description(.debug, "Main.MainTabBar.Tab.Home") case home
}

String(reflecting: TabIndex.chat)  // "Main.MainTabBar.Tab.Chat"
```

### Your own properties

Any other name generates a `String` property of that name, for example to satisfy
a protocol of your own. Declare the protocol on the type yourself, and add
`@DescribableProperties`, which supplies the property:

```swift
protocol AnalyticsNaming {
    var analyticsName: String { get }
}

@Describable
@DescribableProperties
enum Screen: AnalyticsNaming {
    @Description("analyticsName", "chat_room")
    case chat(roomId: Int)
    case home                      // analyticsName == "home"
}
```

Custom properties need their own macro because their names are chosen by you, which
requires the macro to declare arbitrary member names. Declaring those on
`@Describable` itself trips a compiler bug on types whose `Equatable` conformance
can't be synthesized, such as an enum with a closure payload and a hand-written
`==`. Without `@DescribableProperties`, a custom target is a compile error with a
fix-it that adds it.

## Diagnostics

Every mistake is reported during expansion, pointing inside the template where
possible:

| Problem | Diagnostic | Fix-it |
| --- | --- | --- |
| Misspelled field | `unknown description field 'resorce'; available fields: {resource}` | Replace with the closest match |
| Positional index out of range | `description field '{2}' does not exist; case 'value' has 1 associated value` | |
| Unsupported placeholder | `'{name.uppercased()}' is not supported in a description template; …` | |
| Unbalanced brace | `unterminated description placeholder; use '{{' for a literal '{'` | Escape the brace |
| Invalid raw expression | `'{name.}' is not a valid Swift expression` | |
| Struct/class/actor without text | `@Describable requires a description template when applied to a struct` | Insert a memberwise `@Description` |
| `.error` on a non-error | `'.error' is only available for types conforming to Error` | Add `Error` conformance |
| Actor-isolated state | `'{jobs}' refers to actor-isolated state and cannot be used in a synchronous description` | |
| Custom property without `@DescribableProperties` | `custom description property 'analyticsName' requires @DescribableProperties` | Add `@DescribableProperties` |
| Two templates for one target | `description is already configured for this declaration` | Remove the duplicate |
| Existing conformance | `'Foo' already declares a conformance to 'CustomStringConvertible'; …` | Remove it, or replace `LocalizedError` with `Error` |
| Conformance from a superclass or extension | `'Foo' already conforms to 'CustomStringConvertible' through a superclass or an extension; …` | |
| Hand-written member | `'description' is already implemented; …` | |
| Not a type | `@Describable can only be applied to enum, struct, class, or actor declarations` | |

## Limitations

`@Describable` works on syntax. It doesn't repeat the type checker's semantic lookup,
which keeps it predictable but has consequences:

- **`Error` must be in the declaration's own inheritance clause.** A conformance
  added in an extension (`extension Foo: Error {}`), or through a protocol that
  refines `Error`, isn't detected. Move `Error` onto the declaration.
- **Only properties declared in the type's body are visible.** Superclass members,
  protocol requirements, and properties added in extensions can't be used as
  placeholders. Raw templates can use any member, because the compiler checks them.
- **Existing conformances can't be replaced.** A class that already conforms to
  `CustomStringConvertible` through its superclass (for example, any `NSObject`
  subclass, or a subclass of another `@Describable` class) is rejected, because the
  generated `description` can't override the inherited one. The same applies to a
  conformance declared in an extension elsewhere; remove it there.
- **Templates must be single-line string literals** (raw strings are fine).
- **Extension macros can't be attached to types declared inside functions.**
- **Class-based errors on Linux before Swift 6.2:** Foundation crashes when
  `localizedDescription` is called on any class that conforms to `Error`, with or
  without `@Describable`. Read `errorDescription` directly, or use a struct or enum
  error.

## Migrating

From 0.2 to 0.3, add `@DescribableProperties` to types that use custom properties
(`@Description("name", …)` or `.property("name")`). Everything else is unchanged.

From 0.1:

| 0.1 | 0.2 and later |
| --- | --- |
| `@Describable("User({id})")` | `@Describable` `@Description("User({id})")` |
| `@Describable("…", error: "…")` | `@Describable` `@Description("…")` `@Description(.error, "…")` |
| `@Description("…", error: "…")` on a case | `@Description("…")` `@Description(.error, "…")` |
| `@Description(error: "…")` on a case | `@Description(.error, "…")` |

## License

Description is available under the MIT license. See [LICENSE](LICENSE) for details.
