import Foundation

/// Enables synthesized descriptions for an enum, struct, class, or actor.
///
/// `@Describable` only switches synthesis on; the text comes from
/// ``Description(_:)`` attributes on the type and, for enums, on its cases:
///
/// ```swift
/// @Describable
/// @Description("User(id: {id}, name: {name})")
/// struct User {
///     let id: Int
///     let name: String
/// }
/// ```
///
/// By default the macro generates `CustomStringConvertible`, and additionally
/// `LocalizedError` when the declaration lists `Error` in its inheritance
/// clause. Every target that has a `@Description` is generated too, such as
/// `.debug`. Custom properties additionally need ``DescribableProperties()``.
///
/// - Parameters:
///   - generating: The targets to generate instead of the defaults, e.g.
///     `[.debug]` for a type that should only be
///     `CustomDebugStringConvertible`.
///   - default: Where the main text comes from when there is no untargeted
///     `@Description`: the case name for enums, or a member such as
///     `.rawValue`.
@attached(
    extension,
    conformances: CustomStringConvertible, CustomDebugStringConvertible, LocalizedError,
    names: named(description), named(debugDescription), named(errorDescription)
)
@attached(peer)
public macro Describable(
    generating: Set<DescriptionTarget> = [],
    default: DescriptionSource = .caseName
) = #externalMacro(module: "DescriptionMacros", type: "DescribableMacro")

/// Generates the custom properties configured with `@Description("name", ...)`
/// on a `@Describable` type:
///
/// ```swift
/// @Describable
/// @DescribableProperties
/// enum Screen: AnalyticsNaming {
///     @Description("analyticsName", "chat_room")
///     case chat(roomId: Int)
/// }
/// ```
///
/// Custom properties need their own macro because introducing members with
/// names chosen by the user requires `names: arbitrary`. Declaring arbitrary
/// names on `@Describable` itself would trigger a compiler bug on types whose
/// `Equatable` conformance cannot be synthesized, such as enums with closure
/// payloads and a hand-written `==`.
@attached(extension, names: arbitrary)
public macro DescribableProperties() = #externalMacro(module: "DescriptionMacros", type: "DescribablePropertiesMacro")

/// The main text of a type or enum case: `description`, and the fallback for
/// every other target without its own text.
///
/// Placeholders refer to properties declared in the type's body, or to an enum
/// case's associated values by label (`{code}`) or position (`{0}`). They may
/// use member paths (`{info.id}`), optional chaining (`{user?.name}`), a
/// literal default (`{user?.name ?? "anonymous"}`), and presence checks
/// (`{user?}`, rendering `true` or `false`). Use `{{` and `}}` for literal
/// braces.
@attached(peer)
public macro Description(
    _ template: String
) = #externalMacro(module: "DescriptionMacros", type: "DescriptionMacro")

/// The text of one target, such as `.error`, `.debug`, or a custom property:
///
/// ```swift
/// @Describable
/// enum LoadError: Error {
///     @Description("loadFailed({0})")
///     @Description(.error, "Could not load {0}.")
///     @Description("analyticsName", "load_failed")
///     case loadFailed(URL)
/// }
/// ```
@attached(peer)
public macro Description(
    _ target: DescriptionTarget,
    _ template: String
) = #externalMacro(module: "DescriptionMacros", type: "DescriptionMacro")

/// Raw main text: each `{...}` holds any Swift expression, copied into the
/// generated code. A raw string literal avoids escaping quotes:
///
/// ```swift
/// @Description(raw: #"webGame(gameId: {config.gameId ?? "nil"}, count: {items.filter(\.isActive).count})"#)
/// case webGame(config: GameConfig, items: [Item])
/// ```
///
/// Expressions can use the type's members and, in enum cases, associated
/// values by label, or `_0`, `_1`, ... when unlabeled. The macro checks that
/// each expression parses; the compiler checks everything else.
@attached(peer)
public macro Description(
    raw template: String
) = #externalMacro(module: "DescriptionMacros", type: "DescriptionMacro")

/// Raw text for one target, e.g.
/// `@Description(.error, raw: #"{String(localized: "load_failed", bundle: .module)}"#)`.
@attached(peer)
public macro Description(
    _ target: DescriptionTarget,
    raw template: String
) = #externalMacro(module: "DescriptionMacros", type: "DescriptionMacro")

/// A `String` property that `@Describable` generates.
///
/// Use a string literal, or ``property(_:)``, to generate a property of your
/// own, for example one required by your own protocol. Declare that protocol
/// on the type yourself and add ``DescribableProperties()``, which supplies
/// the property.
public struct DescriptionTarget: Hashable, Sendable, ExpressibleByStringLiteral {
    /// The property's name.
    public let name: String

    /// `description`, from `CustomStringConvertible`.
    public static let description = DescriptionTarget(name: "description")
    /// `errorDescription`, from `LocalizedError`.
    public static let error = DescriptionTarget(name: "errorDescription")
    /// `debugDescription`, from `CustomDebugStringConvertible`.
    public static let debug = DescriptionTarget(name: "debugDescription")

    /// A property of your own named `name`.
    public static func property(_ name: String) -> DescriptionTarget {
        DescriptionTarget(name: name)
    }

    public init(stringLiteral name: String) {
        self.init(name: name)
    }

    private init(name: String) {
        self.name = name
    }
}

/// Where `@Describable` takes the main text from when a declaration has no
/// untargeted `@Description`.
///
/// ```swift
/// @Describable(default: .rawValue)
/// enum PayErrorCode: Int, Error {
///     case timeout = 1016   // description == "1016"
/// }
/// ```
public struct DescriptionSource: Hashable, Sendable {
    /// The member interpolated for each value, or `nil` for the case name.
    public let memberName: String?

    /// The enum case's name. The default for enums; structs, classes, and
    /// actors need a template or a member instead.
    public static let caseName = DescriptionSource(memberName: nil)
    /// The raw value of a `RawRepresentable` type.
    public static let rawValue = DescriptionSource(memberName: "rawValue")

    /// A member of `self`, such as a computed `title` property.
    public static func member(_ name: String) -> DescriptionSource {
        DescriptionSource(memberName: name)
    }

    private init(memberName: String?) {
        self.memberName = memberName
    }
}

/// `LocalizedError`, re-exposed so that code generated by `@Describable` can
/// name the protocol in files that do not import Foundation themselves.
///
/// This is an implementation detail of the macro; use `LocalizedError`
/// directly in your own code.
public typealias _DescribableLocalizedError = LocalizedError
