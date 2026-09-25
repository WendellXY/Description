/// Identifies the value a placeholder refers to.
///
/// The parser does not know whether a binding will eventually resolve to an
/// enum associated value or to a property; that is decided during resolution.
enum BindingReference: Hashable, Sendable {
    /// `{name}`: a labeled associated value or a property.
    case named(String)
    /// `{0}`: an associated value by position.
    case positional(Int)
}

extension BindingReference: CustomStringConvertible {
    /// The placeholder spelling, including braces, e.g. `{name}` or `{0}`.
    var description: String {
        switch self {
        case let .named(name): "{\(name)}"
        case let .positional(index): "{\(index)}"
        }
    }
}

/// One `.member` or `?.member` step of a placeholder path.
struct MemberAccess: Equatable, Sendable {
    let name: String
    /// `?.member` rather than `.member`.
    let isOptionalChained: Bool
}

/// How a placeholder's path is turned into interpolated text.
enum PlaceholderForm: Equatable, Sendable {
    /// `{path}`: the value itself.
    case value
    /// `{path ?? literal}`: the value, or a literal default when it is `nil`.
    /// The payload is the default as a Swift expression, e.g. `0` or `"nil"`.
    case coalesced(defaultExpression: String)
    /// `{path?}`: whether the value is non-`nil`, rendered as `true`/`false`.
    case presence
}

/// A placeholder occurrence inside a template.
struct Placeholder: Equatable, Sendable {
    /// The binding the path starts from.
    let reference: BindingReference
    /// Member accesses applied to the binding, e.g. `.info.redPacketId`.
    let members: [MemberAccess]
    let form: PlaceholderForm
    /// UTF-8 offsets of the placeholder, braces included, within the raw
    /// template text.
    let range: Range<Int>
    /// UTF-8 offsets of the root name or index within the raw template text.
    let rootRange: Range<Int>

    init(
        reference: BindingReference,
        members: [MemberAccess] = [],
        form: PlaceholderForm = .value,
        range: Range<Int>,
        rootLength: Int? = nil
    ) {
        self.reference = reference
        self.members = members
        self.form = form
        self.range = range
        let length = rootLength ?? reference.description.utf8.count - 2
        self.rootRange = (range.lowerBound + 1)..<(range.lowerBound + 1 + length)
    }

    /// Whether the path uses `?.`, making a plain value optional.
    var hasOptionalChaining: Bool {
        members.contains(where: \.isOptionalChained)
    }
}

/// An expression from a raw template, copied into generated code as is.
struct RawExpression: Equatable, Sendable {
    /// The expression as Swift source, with the template literal's own
    /// escaping (such as `\"` in an ordinary string literal) removed.
    let source: String
    /// UTF-8 offsets of the expression, braces included, within the raw
    /// template text.
    let range: Range<Int>
}

/// How a template's placeholders are interpreted.
enum TemplateMode: Sendable {
    /// `{path}` placeholders, validated by the macro.
    case checked
    /// `{expression}` placeholders holding any Swift expression, checked only
    /// by the compiler.
    case raw
}

/// A piece of a parsed template.
enum Segment: Equatable, Sendable {
    /// Literal text in source form. Escape sequences are kept verbatim so the
    /// text can be copied into a generated string literal that uses the same
    /// raw-string delimiter as the template; `{{` and `}}` are already
    /// collapsed to single braces.
    case literal(String)
    case placeholder(Placeholder)
    /// `{...}` in a raw template: any Swift expression.
    case expression(RawExpression)
}

/// A parsed description template such as `"User(id: {id})"`.
struct Template: Equatable, Sendable {
    let segments: [Segment]

    var placeholders: [Placeholder] {
        segments.compactMap { segment in
            if case let .placeholder(placeholder) = segment { placeholder } else { nil }
        }
    }
}

/// A syntax problem found while parsing a template.
struct TemplateSyntaxError: Error, Equatable, Sendable {
    enum Kind: Error, Equatable, Sendable {
        /// A `{` without a matching `}`.
        case unterminatedPlaceholder
        /// A `}` that does not close a placeholder.
        case unmatchedClosingBrace
        /// `{}`.
        case emptyPlaceholder
        /// `{value:02X}`; format specifiers are not supported.
        case formatSpecifier(String)
        /// `{a + b}` or `{name.uppercased()}`; only paths are supported.
        case unsupportedExpression(String)
        /// `{value ?? someVariable}`; defaults must be literals.
        case invalidDefault(String)
        /// Anything else that is neither an identifier nor an index.
        case invalidPlaceholder(String)
    }

    let kind: Kind
    /// UTF-8 offsets of the offending text within the raw template text.
    let range: Range<Int>
}

/// All syntax problems found in a template.
struct TemplateParseFailure: Error, Equatable, Sendable {
    let errors: [TemplateSyntaxError]
}
