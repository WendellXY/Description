/// Parses the content between a placeholder's braces:
///
/// ```text
/// {root}                     root = identifier | index
/// {root.member?.member}      member paths, with optional chaining
/// {path ?? literal}          literal = integer | float | "string" | true | false | nil
/// {path?}                    presence: `path != nil`
/// ```
///
/// Anything else (calls, operators, format specifiers) is rejected; arbitrary
/// expressions belong in `@RawDescription`.
enum PlaceholderExpressionParser {
    struct Parsed: Equatable {
        let reference: BindingReference
        let rootLength: Int
        let members: [MemberAccess]
        let form: PlaceholderForm
    }

    private static let coalescingOperator = "??"
    private static let expressionCharacters = Set("()+-*/%<>=&|![]^~,\"")

    static func parse(_ content: String, rawDelimiterLength: Int) -> Result<Parsed, TemplateSyntaxError.Kind> {
        if content.isEmpty {
            return .failure(.emptyPlaceholder)
        }
        if let operatorStart = firstIndex(of: coalescingOperator, in: content) {
            let operatorEnd = content.index(operatorStart, offsetBy: coalescingOperator.count)
            let pathText = content[..<operatorStart].trimmingSpaces
            let defaultText = content[operatorEnd...].trimmingSpaces
            guard let path = parsePath(pathText) else {
                return .failure(failure(for: content))
            }
            guard let defaultExpression = literalExpression(defaultText, rawDelimiterLength: rawDelimiterLength) else {
                return .failure(.invalidDefault(defaultText))
            }
            return .success(path.with(form: .coalesced(defaultExpression: defaultExpression)))
        }
        if content.count > 1, content.hasSuffix("?"), let path = parsePath(content.dropLast()) {
            return .success(path.with(form: .presence))
        }
        if let path = parsePath(content) {
            return .success(path.with(form: .value))
        }
        return .failure(failure(for: content))
    }

    private static func firstIndex(of needle: String, in text: String) -> String.Index? {
        text.indices.first { text[$0...].hasPrefix(needle) }
    }

    private static func failure(for content: String) -> TemplateSyntaxError.Kind {
        if content.contains(":") {
            return .formatSpecifier(content)
        }
        if content.contains(where: expressionCharacters.contains) {
            return .unsupportedExpression(content)
        }
        return .invalidPlaceholder(content)
    }

    private struct Path {
        let reference: BindingReference
        let rootLength: Int
        let members: [MemberAccess]

        func with(form: PlaceholderForm) -> Parsed {
            Parsed(reference: reference, rootLength: rootLength, members: members, form: form)
        }
    }

    private static func parsePath(_ text: some StringProtocol) -> Path? {
        let characters = Array(text)
        let rootEnd = characters.firstIndex { $0 == "." || $0 == "?" } ?? characters.count
        let root = String(characters[..<rootEnd])
        let reference: BindingReference
        if !root.isEmpty, root.allSatisfy(\.isASCIIDigit), let index = Int(root) {
            reference = .positional(index)
        } else if isIdentifier(root) {
            reference = .named(root)
        } else {
            return nil
        }
        guard let members = parseMembers(characters[rootEnd...]) else {
            return nil
        }
        return Path(reference: reference, rootLength: root.utf8.count, members: members)
    }

    /// Parses `.a?.b.c` into member accesses.
    private static func parseMembers(_ characters: ArraySlice<Character>) -> [MemberAccess]? {
        var remaining = characters
        var members: [MemberAccess] = []
        while !remaining.isEmpty {
            let isOptionalChained = remaining.starts(with: ["?", "."])
            guard isOptionalChained || remaining.first == "." else { return nil }
            remaining = remaining.dropFirst(isOptionalChained ? 2 : 1)
            let nameEnd = remaining.firstIndex { $0 == "." || $0 == "?" } ?? remaining.endIndex
            let name = String(remaining[..<nameEnd])
            // Tuple elements (`.0`) are members too.
            guard isIdentifier(name) || (!name.isEmpty && name.allSatisfy(\.isASCIIDigit)) else { return nil }
            members.append(MemberAccess(name: name, isOptionalChained: isOptionalChained))
            remaining = remaining[nameEnd...]
        }
        return members
    }

    /// The default after `??` as a Swift expression, or `nil` if it is not a
    /// supported literal. In ordinary string literals the quotes of a string
    /// default are escaped (`\"nil\"`); in raw strings they are not.
    private static func literalExpression(_ text: String, rawDelimiterLength: Int) -> String? {
        if ["true", "false", "nil"].contains(text) || isNumber(text) {
            return text
        }
        let quote = rawDelimiterLength == 0 ? "\\\"" : "\""
        guard text.count >= 2 * quote.count, text.hasPrefix(quote), text.hasSuffix(quote) else {
            return nil
        }
        let contents = text.dropFirst(quote.count).dropLast(quote.count)
        guard !contents.contains("\""), !contents.contains("\\") else {
            return nil
        }
        return "\"\(contents)\""
    }

    private static func isNumber(_ text: String) -> Bool {
        let unsigned = text.hasPrefix("-") ? text.dropFirst() : Substring(text)
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        return (1...2).contains(parts.count) && parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }
    }

    static func isIdentifier(_ text: some StringProtocol) -> Bool {
        guard let first = text.first, first == "_" || first.isLetter else { return false }
        return text.dropFirst().allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
    }
}

extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

private extension StringProtocol {
    var trimmingSpaces: String {
        String(drop { $0 == " " }.reversed().drop { $0 == " " }.reversed())
    }
}
