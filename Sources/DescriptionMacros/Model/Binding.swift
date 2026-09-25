import SwiftSyntax

/// A template whose placeholders have been resolved to Swift expressions.
struct ResolvedTemplate: Equatable {
    enum Segment: Equatable {
        /// Literal source text, escape sequences included.
        case literal(String)
        /// An expression to interpolate, e.g. `resource` or `self.name`.
        case interpolation(String)
    }

    let segments: [Segment]
    /// The `#` delimiter the generated literal must use so that escape
    /// sequences copied from the template keep their meaning.
    let rawDelimiter: String

    /// A template consisting of a single piece of literal text that needs no
    /// escaping, such as an enum case name.
    static func plain(_ text: String) -> ResolvedTemplate {
        ResolvedTemplate(segments: [.literal(text)], rawDelimiter: "")
    }

    /// The template as a Swift string literal, e.g. `"Loading \(resource)"`.
    var stringLiteral: String {
        let body = segments.map { segment in
            switch segment {
            case let .literal(text): text
            case let .interpolation(expression): "\\\(rawDelimiter)(\(expression))"
            }
        }
        return "\(rawDelimiter)\"\(body.joined())\"\(rawDelimiter)"
    }
}

/// An enum associated value that templates can refer to.
struct AssociatedValue: Equatable {
    /// The zero-based position within the case's associated values.
    let index: Int
    /// The label (or internal name) of the value, if it has one.
    let label: String?
    /// Whether the value's type is spelled as an optional.
    let isOptional: Bool

    /// The name the generated `case let` pattern binds the value to.
    var bindingName: String {
        label.map(SwiftIdentifier.escaped) ?? "_\(index)"
    }

    /// The name raw template expressions use for the value: its label, or
    /// `_0`, `_1`, ... for unlabeled values.
    var referenceName: String {
        label ?? "_\(index)"
    }

    /// How the value is spelled in diagnostics.
    var placeholderSpelling: String {
        label.map { "{\($0)}" } ?? "{\(index)}"
    }
}

enum Interpolation {
    /// The expression interpolated for a value named `name`.
    ///
    /// Optionals are wrapped in `String(describing:)`, which prints exactly
    /// what plain interpolation prints but without the compiler warning about
    /// implicitly using an optional's debug description.
    static func expression(for name: String, isOptional: Bool) -> String {
        isOptional ? "String(describing: \(name))" : name
    }

    /// The expression interpolated for `placeholder` once its root has been
    /// resolved to `root`, e.g. `notify?.uid ?? 0` or `data != nil`.
    static func expression(for placeholder: Placeholder, root: String, rootIsOptional: Bool) -> String {
        let path = root + placeholder.members.map { ($0.isOptionalChained ? "?." : ".") + $0.name }.joined()
        switch placeholder.form {
        case .value:
            let isOptional = placeholder.members.isEmpty ? rootIsOptional : placeholder.hasOptionalChaining
            return expression(for: path, isOptional: isOptional)
        case let .coalesced(defaultExpression):
            return "\(path) ?? \(defaultExpression)"
        case .presence:
            return "\(path) != nil"
        }
    }
}

enum SwiftIdentifier {
    /// Keywords that must be wrapped in backticks to be used as a variable name.
    private static let reservedWords: Set<String> = [
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import", "init",
        "inout", "internal", "let", "open", "operator", "private", "precedencegroup", "protocol", "public",
        "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue",
        "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return",
        "throw", "switch", "where", "while", "Any", "as", "await", "false", "is", "nil", "self", "Self",
        "super", "throws", "true", "try",
    ]

    static func escaped(_ name: String) -> String {
        reservedWords.contains(name) ? "`\(name)`" : name
    }
}

extension TypeSyntax {
    /// Whether the type is written as `T?`, `T!`, or `Optional<T>`.
    var isSpelledAsOptional: Bool {
        if `is`(OptionalTypeSyntax.self) || `is`(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return true
        }
        if let identifier = `as`(IdentifierTypeSyntax.self) {
            return identifier.name.text == "Optional" && identifier.genericArgumentClause != nil
        }
        if let member = `as`(MemberTypeSyntax.self) {
            return member.baseType.trimmedDescription == "Swift" && member.name.text == "Optional"
        }
        return false
    }
}
