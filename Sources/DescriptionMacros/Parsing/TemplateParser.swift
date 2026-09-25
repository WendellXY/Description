/// Parses the description template DSL:
///
/// ```text
/// {name}   named binding, possibly a path (see PlaceholderExpressionParser)
/// {0}      positional binding
/// {{       literal {
/// }}       literal }
/// ```
///
/// In raw templates each `{...}` holds any Swift expression instead; braces
/// inside it (closures, string literals) are balanced rather than parsed.
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
    private static let quote = UInt8(ascii: "\"")

    /// Parses `rawText`.
    ///
    /// - Parameters:
    ///   - rawText: The literal's content exactly as written in source.
    ///   - rawDelimiterLength: The number of `#` characters delimiting the
    ///     literal; escape sequences in raw strings start with `\#`.
    /// - Throws: A ``TemplateParseFailure`` listing every problem found.
    static func parse(
        _ rawText: String,
        rawDelimiterLength: Int = 0,
        mode: TemplateMode = .checked
    ) throws(TemplateParseFailure) -> Template {
        var scanner = Scanner(bytes: Array(rawText.utf8), rawDelimiterLength: rawDelimiterLength, mode: mode)
        scanner.scan()
        guard scanner.errors.isEmpty else {
            throw TemplateParseFailure(errors: scanner.errors)
        }
        return Template(segments: scanner.segments)
    }

    private struct Scanner {
        let bytes: [UInt8]
        let rawDelimiterLength: Int
        let mode: TemplateMode
        private(set) var segments: [Segment] = []
        private(set) var errors: [TemplateSyntaxError] = []
        private var literal: [UInt8] = []
        private var index = 0

        init(bytes: [UInt8], rawDelimiterLength: Int, mode: TemplateMode) {
            self.bytes = bytes
            self.rawDelimiterLength = rawDelimiterLength
            self.mode = mode
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
            if mode == .raw {
                consumeExpression()
                return
            }
            guard let close = closingBrace(after: index) else {
                errors.append(TemplateSyntaxError(kind: .unterminatedPlaceholder, range: index..<(index + 1)))
                index += 1
                return
            }
            let range = index..<(close + 1)
            let content = String(decoding: bytes[(index + 1)..<close], as: UTF8.self)
            switch PlaceholderExpressionParser.parse(content, rawDelimiterLength: rawDelimiterLength) {
            case let .success(parsed):
                flushLiteral()
                segments.append(.placeholder(Placeholder(
                    reference: parsed.reference,
                    members: parsed.members,
                    form: parsed.form,
                    range: range,
                    rootLength: parsed.rootLength
                )))
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

        /// Reads `{expression}` in a raw template.
        private mutating func consumeExpression() {
            guard let close = balancedClosingBrace(after: index) else {
                errors.append(TemplateSyntaxError(kind: .unterminatedPlaceholder, range: index..<(index + 1)))
                index += 1
                return
            }
            let range = index..<(close + 1)
            let source = unescapedSource(bytes[(index + 1)..<close])
            if source.allSatisfy({ $0 == " " }) {
                errors.append(TemplateSyntaxError(kind: .emptyPlaceholder, range: range))
            } else {
                flushLiteral()
                segments.append(.expression(RawExpression(source: source, range: range)))
            }
            index = close + 1
        }

        /// The offset of the `}` matching the `{` at `start`, skipping nested
        /// braces and string literals inside the expression.
        private func balancedClosingBrace(after start: Int) -> Int? {
            var depth = 1
            var isInString = false
            var offset = start + 1
            while offset < bytes.count {
                let current = bytes[offset]
                if rawDelimiterLength == 0, current == TemplateParser.backslash {
                    // In an ordinary literal, `\"` delimits nested strings.
                    if byte(at: offset + 1) == TemplateParser.quote {
                        isInString.toggle()
                    }
                    offset += 2
                    continue
                }
                if rawDelimiterLength > 0, current == TemplateParser.quote {
                    isInString.toggle()
                } else if !isInString, current == TemplateParser.openBrace {
                    depth += 1
                } else if !isInString, current == TemplateParser.closeBrace {
                    depth -= 1
                    if depth == 0 { return offset }
                }
                offset += 1
            }
            return nil
        }

        /// The expression as Swift source. An ordinary literal escapes quotes
        /// and backslashes (`\"`, `\\`); a raw literal needs no escaping.
        private func unescapedSource(_ slice: ArraySlice<UInt8>) -> String {
            guard rawDelimiterLength == 0 else {
                return String(decoding: slice, as: UTF8.self)
            }
            var result: [UInt8] = []
            var offset = slice.startIndex
            while offset < slice.endIndex {
                let byte = slice[offset]
                if byte == TemplateParser.backslash, offset + 1 < slice.endIndex,
                   [TemplateParser.quote, TemplateParser.backslash].contains(slice[offset + 1]) {
                    result.append(slice[offset + 1])
                    offset += 2
                } else {
                    result.append(byte)
                    offset += 1
                }
            }
            return String(decoding: result, as: UTF8.self)
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

    }
}
