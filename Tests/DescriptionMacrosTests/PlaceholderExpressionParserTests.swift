@testable import DescriptionMacros
import Testing

@Suite("PlaceholderExpressionParser")
struct PlaceholderExpressionParserTests {
    private func parse(_ content: String, rawDelimiterLength: Int = 0) -> Result<PlaceholderExpressionParser.Parsed, TemplateSyntaxError.Kind> {
        PlaceholderExpressionParser.parse(content, rawDelimiterLength: rawDelimiterLength)
    }

    private func member(_ name: String, optional: Bool = false) -> MemberAccess {
        MemberAccess(name: name, isOptionalChained: optional)
    }

    @Test func plainNameAndIndex() {
        #expect(parse("name") == .success(.init(reference: .named("name"), rootLength: 4, members: [], form: .value)))
        #expect(parse("12") == .success(.init(reference: .positional(12), rootLength: 2, members: [], form: .value)))
    }

    @Test func memberPathsAndOptionalChaining() {
        #expect(parse("notify?.level.value") == .success(.init(
            reference: .named("notify"),
            rootLength: 6,
            members: [member("level", optional: true), member("value")],
            form: .value
        )))
        #expect(parse("0.count") == .success(.init(reference: .positional(0), rootLength: 1, members: [member("count")], form: .value)))
        #expect(parse("pair.1") == .success(.init(reference: .named("pair"), rootLength: 4, members: [member("1")], form: .value)))
    }

    @Test func literalDefaults() {
        #expect(parse("notify?.uid ?? 0") == .success(.init(
            reference: .named("notify"),
            rootLength: 6,
            members: [member("uid", optional: true)],
            form: .coalesced(defaultExpression: "0")
        )))
        #expect(parse("a??-1.5") == .success(.init(reference: .named("a"), rootLength: 1, members: [], form: .coalesced(defaultExpression: "-1.5"))))
        #expect(parse("a ?? false") == .success(.init(reference: .named("a"), rootLength: 1, members: [], form: .coalesced(defaultExpression: "false"))))
        #expect(parse("a ?? nil") == .success(.init(reference: .named("a"), rootLength: 1, members: [], form: .coalesced(defaultExpression: "nil"))))
    }

    @Test func stringDefaultsFollowTheLiteralsEscaping() {
        // In "…" the quotes are written \"nil\"; in #"…"# they are plain.
        #expect(parse(#"id ?? \"nil\""#) == .success(.init(reference: .named("id"), rootLength: 2, members: [], form: .coalesced(defaultExpression: #""nil""#))))
        #expect(parse(#"id ?? "nil""#, rawDelimiterLength: 1) == .success(.init(reference: .named("id"), rootLength: 2, members: [], form: .coalesced(defaultExpression: #""nil""#))))
        #expect(parse(#"id ?? "nil""#) == .failure(.invalidDefault(#""nil""#)))
    }

    @Test func presence() {
        #expect(parse("state.resumeGameData?") == .success(.init(
            reference: .named("state"),
            rootLength: 5,
            members: [member("resumeGameData")],
            form: .presence
        )))
    }

    @Test(arguments: ["a ?? b", "a ?? 1 + 2", "a ?? "])
    func nonLiteralDefaultsAreRejected(content: String) {
        guard case .failure(.invalidDefault) = parse(content) else {
            Issue.record("Expected invalidDefault for \(content)")
            return
        }
    }

    @Test(arguments: ["name.uppercased()", "a + b", "a == b", "items[0]", "!flag"])
    func expressionsAreRejected(content: String) {
        #expect(parse(content) == .failure(.unsupportedExpression(content)))
    }

    @Test func formatSpecifiersAreStillRejected() {
        #expect(parse("value:02X") == .failure(.formatSpecifier("value:02X")))
    }
}
