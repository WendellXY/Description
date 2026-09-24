/// Parses the description template DSL:
///
/// ```text
/// {name}   named binding
/// {0}      positional binding
/// {{       literal {
/// }}       literal }
/// ```
///
/// The parser operates on the raw source text of a single-line string literal
/// so that escape sequences survive unchanged into generated code and so that
/// diagnostics can point at exact source offsets.
enum TemplateParser {
    private static let backslash = UInt8(ascii: "\\")
    private static let pound = UInt8(ascii: "#")
    private static let openBrace = UInt8(ascii: "{")
    private static let closeBrace = UInt8(ascii: "}")
    private static let unicodeEscape = UInt8(ascii: "u")

    /// Parses `rawText`.
    ///
    /// - Parameters:
    ///   - rawText: The literal's content exactly as written in source.
    ///   - rawDelimiterLength: The number of `#` characters delimiting the
    ///     literal; escape sequences in raw strings start with `\#`.
    /// - Throws: A ``TemplateParseFailure`` listing every problem found.
    static func parse(
        _ rawText: String,
        rawDelimiterLength: Int = 0
    ) throws(TemplateParseFailure) -> Template {
        var scanner = Scanner(bytes: Array(rawText.utf8), rawDelimiterLength: rawDelimiterLength)
        scanner.scan()
        guard scanner.errors.isEmpty else {
            throw TemplateParseFailure(errors: scanner.errors)
        }
        return Template(segments: scanner.segments)
    }

    private struct Scanner {
        let bytes: [UInt8]
        let rawDelimiterLength: Int
        private(set) var segments: [Segment] = []
        private(set) var errors: [TemplateSyntaxError] = []
        private var literal: [UInt8] = []
        private var index = 0

        init(bytes: [UInt8], rawDelimiterLength: Int) {
            self.bytes = bytes
            self.rawDelimiterLength = rawDelimiterLength
        }

        mutating func scan() {
            while index < bytes.count {
                switch bytes[index] {
                case TemplateParser.backslash where isEscapeStart(at: index):
                    consumeEscape()
                case TemplateParser.openBrace:
                    consumeOpenBrace()
                case TemplateParser.closeBrace:
                    consumeCloseBrace()
                default:
                    literal.append(bytes[index])
                    index += 1
                }
            }
            flushLiteral()
        }

        private func byte(at offset: Int) -> UInt8? {
            offset < bytes.count ? bytes[offset] : nil
        }

        private func isEscapeStart(at offset: Int) -> Bool {
            (0..<rawDelimiterLength).allSatisfy { byte(at: offset + 1 + $0) == TemplateParser.pound }
        }

        /// Copies an escape sequence such as `\n`, `\"` or `\u{7B}` verbatim.
        /// Braces inside `\u{...}` must not be mistaken for placeholders.
        private mutating func consumeEscape() {
            let start = index
            index += 1 + rawDelimiterLength
            if byte(at: index) == TemplateParser.unicodeEscape, byte(at: index + 1) == TemplateParser.openBrace {
                while index < bytes.count, bytes[index] != TemplateParser.closeBrace {
                    index += 1
                }
            }
            index = min(index + 1, bytes.count)
            literal.append(contentsOf: bytes[start..<index])
        }

        private mutating func consumeOpenBrace() {
            if byte(at: index + 1) == TemplateParser.openBrace {
                literal.append(TemplateParser.openBrace)
                index += 2
                return
            }
            guard let close = closingBrace(after: index) else {
                errors.append(TemplateSyntaxError(kind: .unterminatedPlaceholder, range: index..<(index + 1)))
                index += 1
                return
            }
            let range = index..<(close + 1)
            let content = String(decoding: bytes[(index + 1)..<close], as: UTF8.self)
            switch Self.classify(content) {
            case let .success(reference):
                flushLiteral()
                segments.append(.placeholder(Placeholder(reference: reference, range: range)))
            case let .failure(kind):
                errors.append(TemplateSyntaxError(kind: kind, range: range))
            }
            index = close + 1
        }

        private mutating func consumeCloseBrace() {
            if byte(at: index + 1) == TemplateParser.closeBrace {
                literal.append(TemplateParser.closeBrace)
                index += 2
                return
            }
            errors.append(TemplateSyntaxError(kind: .unmatchedClosingBrace, range: index..<(index + 1)))
            index += 1
        }

        /// The offset of the `}` closing the placeholder opened at `start`, or
        /// `nil` if another `{` or the end of the text comes first.
        private func closingBrace(after start: Int) -> Int? {
            var offset = start + 1
            while offset < bytes.count {
                switch bytes[offset] {
                case TemplateParser.closeBrace: return offset
                case TemplateParser.openBrace: return nil
                default: offset += 1
                }
            }
            return nil
        }

        private mutating func flushLiteral() {
            guard !literal.isEmpty else { return }
            let text = String(decoding: literal, as: UTF8.self)
            if case let .literal(previous)? = segments.last {
                segments[segments.count - 1] = .literal(previous + text)
            } else {
                segments.append(.literal(text))
            }
            literal = []
        }

        private static func classify(_ content: String) -> Result<BindingReference, TemplateSyntaxError.Kind> {
            if content.isEmpty {
                return .failure(.emptyPlaceholder)
            }
            if content.allSatisfy(\.isASCIIDigit) {
                guard let index = Int(content) else { return .failure(.invalidPlaceholder(content)) }
                return .success(.positional(index))
            }
            if content.contains(":") {
                return .failure(.formatSpecifier(content))
            }
            if content.contains("."), content.split(separator: ".", omittingEmptySubsequences: false).allSatisfy(isIdentifier) {
                return .failure(.memberPath(content))
            }
            if isIdentifier(content) {
                return .success(.named(content))
            }
            return .failure(.invalidPlaceholder(content))
        }

        private static func isIdentifier(_ text: some StringProtocol) -> Bool {
            guard let first = text.first, first == "_" || first.isLetter else { return false }
            return text.dropFirst().allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
        }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
