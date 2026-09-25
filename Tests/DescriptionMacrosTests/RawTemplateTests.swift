@testable import DescriptionMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Raw templates")
struct RawTemplateTests {
    @Test func parserBalancesNestedBracesAndStrings() throws {
        let template = try TemplateParser.parse(##"n={items.map { "}" + $0 }.count}!"##, rawDelimiterLength: 1, mode: .raw)
        #expect(template.segments == [
            .literal("n="),
            .expression(RawExpression(source: #"items.map { "}" + $0 }.count"#, range: 2..<32)),
            .literal("!"),
        ])
    }

    @Test func parserUnescapesOrdinaryLiterals() throws {
        let template = try TemplateParser.parse(#"{a ?? \"nil\"} {{x}}"#, mode: .raw)
        #expect(template.segments == [
            .expression(RawExpression(source: #"a ?? "nil""#, range: 0..<14)),
            .literal(" {x}"),
        ])
    }

    @Test func parserReportsUnterminatedAndEmptyExpressions() {
        #expect(throws: TemplateParseFailure(errors: [
            TemplateSyntaxError(kind: .emptyPlaceholder, range: 0..<3),
            TemplateSyntaxError(kind: .unterminatedPlaceholder, range: 4..<5),
        ])) {
            try TemplateParser.parse("{ } {a.map { $0 }", mode: .raw)
        }
    }

    @Test func enumCasesBindOnlyReferencedValues() {
        assertExpansion(
            ###"""
            @Describable
            enum Route: Error {
                @Description(raw: #"web(id: {config.gameId ?? "nil"}, active: {items.filter { $0.isActive }.count})"#)
                case web(config: GameConfig, items: [Item], flag: Bool)

                @Description(.error, raw: #"{String(localized: "game_lost", bundle: .module)}"#)
                case lost(Int)

                @Description(raw: "{_0.uppercased()}")
                case named(String)
            }
            """###,
            expandedSource: ###"""
            enum Route: Error {
                case web(config: GameConfig, items: [Item], flag: Bool)
                case lost(Int)
                case named(String)
            }

            extension Route: CustomStringConvertible, _DescribableLocalizedError {
                var description: String {
                    switch self {
                    case let .web(config, items, _):
                        return #"web(id: \#(config.gameId ?? "nil"), active: \#(items.filter { $0.isActive }.count))"#
                    case .lost:
                        return "lost"
                    case let .named(_0):
                        return "\(_0.uppercased())"
                    }
                }

                var errorDescription: String? {
                    switch self {
                    case let .web(config, items, _):
                        return #"web(id: \#(config.gameId ?? "nil"), active: \#(items.filter { $0.isActive }.count))"#
                    case .lost:
                        return #"\#(String(localized: "game_lost", bundle: .module))"#
                    case let .named(_0):
                        return "\(_0.uppercased())"
                    }
                }
            }
            """###
        )
    }

    @Test func nominalRawTemplate() {
        assertExpansion(
            ##"""
            @Describable
            @Description(raw: #"User({name.uppercased()}, {tags.joined(separator: ",")})"#)
            struct User {
                let name: String
                let tags: [String]
            }
            """##,
            expandedSource: ##"""
            struct User {
                let name: String
                let tags: [String]
            }

            extension User: CustomStringConvertible {
                var description: String {
                    #"User(\#(name.uppercased()), \#(tags.joined(separator: ",")))"#
                }
            }
            """##
        )
    }

    @Test func invalidExpression() {
        assertExpansion(
            #"""
            @Describable
            @Description(raw: "{name.}")
            struct User {
                let name: String
            }
            """#,
            expandedSource: """
            struct User {
                let name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "'{name.}' is not a valid Swift expression", line: 2, column: 20),
            ]
        )
    }

    @Test func positionalLiteralWarning() {
        assertExpansion(
            #"""
            @Describable
            enum Value {
                @Description(raw: "value={0}")
                case value(Int)
            }
            """#,
            expandedSource: #"""
            enum Value {
                case value(Int)
            }

            extension Value: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .value:
                        return "value=\(0)"
                    }
                }
            }
            """#,
            diagnostics: [
                DiagnosticSpec(
                    message: "'{0}' in a raw template is the integer literal 0; unlabeled associated values are named _0, _1, and so on",
                    line: 3,
                    column: 30,
                    severity: .warning
                ),
            ]
        )
    }
}
