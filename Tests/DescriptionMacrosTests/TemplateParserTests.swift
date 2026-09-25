@testable import DescriptionMacros
import Testing

@Suite("TemplateParser")
struct TemplateParserTests {
    @Test func plainText() throws {
        let template = try TemplateParser.parse("idle")
        #expect(template.segments == [.literal("idle")])
    }

    @Test func emptyText() throws {
        let template = try TemplateParser.parse("")
        #expect(template.segments.isEmpty)
    }

    @Test func namedPlaceholder() throws {
        let template = try TemplateParser.parse("Loading {resource}")
        #expect(template.segments == [
            .literal("Loading "),
            .placeholder(Placeholder(reference: .named("resource"), range: 8..<18)),
        ])
    }

    @Test func positionalPlaceholders() throws {
        let template = try TemplateParser.parse("Expected {0}, got {1}")
        #expect(template.segments == [
            .literal("Expected "),
            .placeholder(Placeholder(reference: .positional(0), range: 9..<12)),
            .literal(", got "),
            .placeholder(Placeholder(reference: .positional(1), range: 18..<21)),
        ])
    }

    @Test func adjacentPlaceholders() throws {
        let template = try TemplateParser.parse("{a}{b}")
        #expect(template.placeholders.map(\.reference) == [.named("a"), .named("b")])
        #expect(template.segments.count == 2)
    }

    @Test func escapedBraces() throws {
        let template = try TemplateParser.parse("Object {{ id: {id} }}")
        #expect(template.segments == [
            .literal("Object { id: "),
            .placeholder(Placeholder(reference: .named("id"), range: 14..<18)),
            .literal(" }"),
        ])
    }

    @Test func onlyEscapedBraces() throws {
        let template = try TemplateParser.parse("{{}}")
        #expect(template.segments == [.literal("{}")])
    }

    @Test func identifiersMayContainUnderscoresDigitsAndUnicode() throws {
        let template = try TemplateParser.parse("{_value1} {naïve}")
        #expect(template.placeholders.map(\.reference) == [.named("_value1"), .named("naïve")])
    }

    @Test func keywordsAreAcceptedAsNames() throws {
        let template = try TemplateParser.parse("{default}")
        #expect(template.placeholders.map(\.reference) == [.named("default")])
    }

    @Test func rangesAreUTF8Offsets() throws {
        let template = try TemplateParser.parse("é {x}")
        #expect(template.placeholders.first?.range == 3..<6)
    }

    @Test func escapeSequencesArePreservedVerbatim() throws {
        let template = try TemplateParser.parse(#"line\n\"{x}\"\\"#)
        #expect(template.segments == [
            .literal(#"line\n\""#),
            .placeholder(Placeholder(reference: .named("x"), range: 8..<11)),
            .literal(#"\"\\"#),
        ])
    }

    @Test func unicodeEscapeBracesAreNotPlaceholders() throws {
        let template = try TemplateParser.parse(#"\u{7B}{x}\u{7D}"#)
        #expect(template.segments == [
            .literal(#"\u{7B}"#),
            .placeholder(Placeholder(reference: .named("x"), range: 6..<9)),
            .literal(#"\u{7D}"#),
        ])
    }

    @Test func rawStringsOnlyTreatDelimitedBackslashesAsEscapes() throws {
        let template = try TemplateParser.parse(##"\{x} \#u{7B}"##, rawDelimiterLength: 1)
        #expect(template.segments == [
            .literal(#"\"#),
            .placeholder(Placeholder(reference: .named("x"), range: 1..<4)),
            .literal(##" \#u{7B}"##),
        ])
    }

    @Test func unterminatedPlaceholder() {
        #expect(throws: TemplateParseFailure(errors: [
            TemplateSyntaxError(kind: .unterminatedPlaceholder, range: 5..<6),
        ])) {
            try TemplateParser.parse("Load {resource")
        }
    }

    @Test func nestedOpenBraceIsUnterminated() {
        #expect(throws: TemplateParseFailure(errors: [
            TemplateSyntaxError(kind: .unterminatedPlaceholder, range: 0..<1),
        ])) {
            try TemplateParser.parse("{a{b}")
        }
    }

    @Test func unmatchedClosingBrace() {
        #expect(throws: TemplateParseFailure(errors: [
            TemplateSyntaxError(kind: .unmatchedClosingBrace, range: 4..<5),
        ])) {
            try TemplateParser.parse("oops} done")
        }
    }

    @Test func emptyPlaceholder() {
        #expect(throws: TemplateParseFailure(errors: [
            TemplateSyntaxError(kind: .emptyPlaceholder, range: 2..<4),
        ])) {
            try TemplateParser.parse("a {} b")
        }
    }

    @Test func memberPathsAreParsed() throws {
        let template = try TemplateParser.parse("id={info.redPacketId}")
        #expect(template.placeholders == [
            Placeholder(
                reference: .named("info"),
                members: [MemberAccess(name: "redPacketId", isOptionalChained: false)],
                range: 3..<21,
                rootLength: 4
            ),
        ])
        #expect(template.placeholders.first?.rootRange == 4..<8)
    }

    @Test func formatSpecifiersAreRejected() {
        #expect(throws: TemplateParseFailure(errors: [
            TemplateSyntaxError(kind: .formatSpecifier("value:02X"), range: 0..<11),
        ])) {
            try TemplateParser.parse("{value:02X}")
        }
    }

    @Test(arguments: ["{ name }", "{1a}", "{-1}", "{a b}", "{a.}", "{a..b}", "{a?}?}", "{?}"])
    func invalidPlaceholders(text: String) {
        #expect(throws: TemplateParseFailure.self) {
            try TemplateParser.parse(text)
        }
    }

    @Test func allErrorsAreReported() {
        // do/catch rather than `#require(throws:)` returning the error, which
        // needs Swift 6.1.
        do {
            _ = try TemplateParser.parse("} {} {x")
            Issue.record("Expected the template to fail to parse")
        } catch {
            #expect(error.errors.map(\.kind) == [.unmatchedClosingBrace, .emptyPlaceholder, .unterminatedPlaceholder])
        }
    }

    @Test func bindingReferenceSpelling() {
        #expect(BindingReference.named("id").description == "{id}")
        #expect(BindingReference.positional(2).description == "{2}")
    }
}
