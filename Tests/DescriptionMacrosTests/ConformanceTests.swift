import SwiftSyntax
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Existing conformances")
struct ConformanceTests {
    @Test func explicitCustomStringConvertible() {
        assertExpansion(
            """
            @Describable
            @Description("Foo")
            struct Foo: Hashable, CustomStringConvertible {
            }
            """,
            expandedSource: """
            struct Foo: Hashable, CustomStringConvertible {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'Foo' already declares a conformance to 'CustomStringConvertible'; @Describable cannot synthesize a conformance that already exists",
                    line: 3,
                    column: 23,
                    fixIts: [FixItSpec(message: "remove 'CustomStringConvertible' conformance")]
                ),
            ],
            conformances: ["LocalizedError"],
            applyFixIts: ["remove 'CustomStringConvertible' conformance"],
            fixedSource: """
            @Describable
            @Description("Foo")
            struct Foo: Hashable {
            }
            """
        )
    }

    @Test func onlyExplicitCustomStringConvertibleRemovesClause() {
        assertExpansion(
            """
            @Describable
            @Description("Foo")
            struct Foo: CustomStringConvertible {
            }
            """,
            expandedSource: """
            struct Foo: CustomStringConvertible {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'Foo' already declares a conformance to 'CustomStringConvertible'; @Describable cannot synthesize a conformance that already exists",
                    line: 3,
                    column: 13,
                    fixIts: [FixItSpec(message: "remove 'CustomStringConvertible' conformance")]
                ),
            ],
            conformances: ["LocalizedError"],
            applyFixIts: ["remove 'CustomStringConvertible' conformance"],
            fixedSource: """
            @Describable
            @Description("Foo")
            struct Foo {
            }
            """
        )
    }

    @Test func manualDescription() {
        assertExpansion(
            """
            @Describable
            @Description("Foo")
            struct Foo {
                var description: String { "manual" }
            }
            """,
            expandedSource: """
            struct Foo {
                var description: String { "manual" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'description' is already implemented; @Describable cannot synthesize 'CustomStringConvertible' for a type that implements it manually",
                    line: 4,
                    column: 5
                ),
            ]
        )
    }

    @Test func manualErrorDescription() {
        assertExpansion(
            """
            @Describable
            @Description("Foo")
            struct Foo: Error {
                var errorDescription: String? { "manual" }
            }
            """,
            expandedSource: """
            struct Foo: Error {
                var errorDescription: String? { "manual" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'errorDescription' is already implemented; @Describable cannot synthesize 'LocalizedError' for a type that implements it manually",
                    line: 4,
                    column: 5
                ),
            ]
        )
    }

    @Test func errorDescriptionOnNonErrorTypeIsUnrelated() {
        assertExpansion(
            """
            @Describable
            @Description("Foo")
            struct Foo {
                var errorDescription: String? { nil }
            }
            """,
            expandedSource: """
            struct Foo {
                var errorDescription: String? { nil }
            }

            extension Foo: CustomStringConvertible {
                var description: String {
                    "Foo"
                }
            }
            """
        )
    }

    @Test func explicitLocalizedErrorIsReplacedWithError() {
        assertExpansion(
            """
            @Describable
            enum Failure: LocalizedError {
                case timeout
            }
            """,
            expandedSource: """
            enum Failure: LocalizedError {
                case timeout
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable synthesizes 'LocalizedError' for types that conform to 'Error'; declare 'Error' instead",
                    line: 2,
                    column: 15,
                    fixIts: [FixItSpec(message: "replace 'LocalizedError' with 'Error'")]
                ),
            ],
            conformances: ["CustomStringConvertible"],
            applyFixIts: ["replace 'LocalizedError' with 'Error'"],
            fixedSource: """
            @Describable
            enum Failure: Error {
                case timeout
            }
            """
        )
    }

    @Test func redundantLocalizedErrorIsRemoved() {
        assertExpansion(
            """
            @Describable
            enum Failure: Error, LocalizedError {
                case timeout
            }
            """,
            expandedSource: """
            enum Failure: Error, LocalizedError {
                case timeout
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable synthesizes 'LocalizedError' for types that conform to 'Error'; declare 'Error' instead",
                    line: 2,
                    column: 22,
                    fixIts: [FixItSpec(message: "remove 'LocalizedError' conformance")]
                ),
            ],
            conformances: ["CustomStringConvertible"],
            applyFixIts: ["remove 'LocalizedError' conformance"],
            fixedSource: """
            @Describable
            enum Failure: Error {
                case timeout
            }
            """
        )
    }

    @Test func conformanceInheritedFromSuperclass() {
        assertExpansion(
            """
            @Describable
            @Description("View({id})")
            final class View: NSObject {
                let id: Int
            }
            """,
            expandedSource: """
            final class View: NSObject {
                let id: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'View' already conforms to 'CustomStringConvertible' through a superclass or an extension; remove that conformance so @Describable can synthesize it",
                    line: 1,
                    column: 1
                ),
            ],
            conformances: ["LocalizedError"]
        )
    }

    @Test func localizedErrorFromExtension() {
        assertExpansion(
            """
            @Describable
            @Description("Failure")
            struct Failure: Error {}

            extension Failure: LocalizedError {}
            """,
            expandedSource: """
            struct Failure: Error {}

            extension Failure: LocalizedError {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'Failure' already conforms to 'LocalizedError' through a superclass or an extension; remove that conformance so @Describable can synthesize it",
                    line: 1,
                    column: 1
                ),
            ],
            conformances: ["CustomStringConvertible"]
        )
    }

    @Test func nonErrorTypesIgnoreLocalizedErrorAvailability() {
        assertExpansion(
            """
            @Describable
            @Description("Foo")
            struct Foo {}
            """,
            expandedSource: """
            struct Foo {}

            extension Foo: CustomStringConvertible {
                var description: String {
                    "Foo"
                }
            }
            """,
            conformances: ["CustomStringConvertible"]
        )
    }
}
