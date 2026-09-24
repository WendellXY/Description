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

/// A placeholder occurrence inside a template.
struct Placeholder: Equatable, Sendable {
    let reference: BindingReference
    /// UTF-8 offsets of the placeholder, braces included, within the raw
    /// template text.
    let range: Range<Int>
}

/// A piece of a parsed template.
enum Segment: Equatable, Sendable {
    /// Literal text in source form. Escape sequences are kept verbatim so the
    /// text can be copied into a generated string literal that uses the same
    /// raw-string delimiter as the template; `{{` and `}}` are already
    /// collapsed to single braces.
    case literal(String)
    case placeholder(Placeholder)
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
        /// `{user.name}`; member paths are not supported.
        case memberPath(String)
        /// `{value:02X}`; format specifiers are not supported.
        case formatSpecifier(String)
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
