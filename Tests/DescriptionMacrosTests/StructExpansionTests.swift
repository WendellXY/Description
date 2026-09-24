import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Struct expansion")
struct StructExpansionTests {
    @Test func multipleProperties() {
        assertExpansion(
            """
            @Describable("User(id: {id}, name: {name})")
            struct User {
                let id: UUID
                let name: String
            }
            """,
            expandedSource: """
            struct User {
                let id: UUID
                let name: String
            }

            extension User: CustomStringConvertible {
                var description: String {
                    "User(id: \\(id), name: \\(name))"
                }
            }
            """
        )
    }

    @Test func computedObservedAndKeywordProperties() {
        assertExpansion(
            """
            @Describable("{total} {count} {default}")
            struct Counter {
                var count: Int { didSet {} }
                var total: Int { count * 2 }
                var `default`: Int?
            }
            """,
            expandedSource: """
            struct Counter {
                var count: Int { didSet {} }
                var total: Int { count * 2 }
                var `default`: Int?
            }

            extension Counter: CustomStringConvertible {
                var description: String {
                    "\\(total) \\(count) \\(String(describing: `default`))"
                }
            }
            """
        )
    }

    @Test func optionalsUseStringDescribing() {
        assertExpansion(
            """
            @Describable("{a} {b} {c} {d}")
            struct Values {
                let a: Int?
                let b: Int!
                let c: Optional<Int>
                let d: [Int?]
            }
            """,
            expandedSource: """
            struct Values {
                let a: Int?
                let b: Int!
                let c: Optional<Int>
                let d: [Int?]
            }

            extension Values: CustomStringConvertible {
                var description: String {
                    "\\(String(describing: a)) \\(String(describing: b)) \\(String(describing: c)) \\(d)"
                }
            }
            """
        )
    }

    @Test func genericStruct() {
        assertExpansion(
            """
            @Describable("Box(value: {value})")
            struct Box<T> {
                let value: T
            }
            """,
            expandedSource: """
            struct Box<T> {
                let value: T
            }

            extension Box: CustomStringConvertible {
                var description: String {
                    "Box(value: \\(value))"
                }
            }
            """
        )
    }

    @Test(arguments: [("public", "public "), ("open", "public "), ("package", "package "), ("fileprivate", ""), ("internal", "")])
    func accessLevels(modifier: String, generated: String) {
        assertExpansion(
            """
            @Describable("x")
            \(modifier) struct Value {
            }
            """,
            expandedSource: """
            \(modifier) struct Value {
            }

            extension Value: CustomStringConvertible {
                \(generated)var description: String {
                    "x"
                }
            }
            """
        )
    }

    @Test func tuplePatternsAndConditionalProperties() {
        assertExpansion(
            """
            @Describable("{a},{b},{c}")
            struct Values {
                let (a, b): (Int, Int)
                #if DEBUG
                let c: Int
                #endif
            }
            """,
            expandedSource: """
            struct Values {
                let (a, b): (Int, Int)
                #if DEBUG
                let c: Int
                #endif
            }

            extension Values: CustomStringConvertible {
                var description: String {
                    "\\(a),\\(b),\\(c)"
                }
            }
            """
        )
    }

    @Test func missingTemplate() {
        assertExpansion(
            """
            @Describable
            struct User {
                let id: UUID
            }
            """,
            expandedSource: """
            struct User {
                let id: UUID
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Describable requires a description template when applied to a struct", line: 1, column: 1),
            ]
        )
    }

    @Test func unknownProperty() {
        assertExpansion(
            """
            @Describable("User({nmae})")
            struct User {
                let id: UUID
                let name: String
                static let shared = 0
            }
            """,
            expandedSource: """
            struct User {
                let id: UUID
                let name: String
                static let shared = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "unknown description field 'nmae'; available fields: {id}, {name}", line: 1, column: 20),
            ]
        )
    }

    @Test func noProperties() {
        assertExpansion(
            """
            @Describable("{x}")
            struct Empty {}
            """,
            expandedSource: """
            struct Empty {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unknown description field 'x'; struct 'Empty' has no fields that can be used in a description",
                    line: 1,
                    column: 15
                ),
            ]
        )
    }

    @Test func staticProperty() {
        assertExpansion(
            """
            @Describable("{shared}")
            struct Config {
                static let shared = Config()
            }
            """,
            expandedSource: """
            struct Config {
                static let shared = Config()
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'{shared}' refers to a static property; only instance properties can be used in a description",
                    line: 1,
                    column: 15
                ),
            ]
        )
    }

    @Test func positionalPlaceholder() {
        assertExpansion(
            """
            @Describable("{0}")
            struct Pair {
                let first: Int
            }
            """,
            expandedSource: """
            struct Pair {
                let first: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "positional description field '{0}' is only available for enum associated values; refer to the properties of struct 'Pair' by name",
                    line: 1,
                    column: 15
                ),
            ]
        )
    }
}
