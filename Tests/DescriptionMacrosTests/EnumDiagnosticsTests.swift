import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Enum diagnostics")
struct EnumDiagnosticsTests {
    @Test func unknownNamedField() {
        assertExpansion(
            """
            @Describable
            enum State {
                @Description("Loading {resorce}")
                case loading(resource: String)
            }
            """,
            expandedSource: """
            enum State {
                case loading(resource: String)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unknown description field 'resorce'; available fields: {resource}",
                    line: 3,
                    column: 27,
                    fixIts: [FixItSpec(message: "replace '{resorce}' with '{resource}'")]
                ),
            ]
        )
    }

    @Test func unknownFieldOnCaseWithoutValues() {
        assertExpansion(
            """
            @Describable
            enum State {
                @Description("{value}")
                case idle
            }
            """,
            expandedSource: """
            enum State {
                case idle
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unknown description field 'value'; case 'idle' has no fields that can be used in a description",
                    line: 3,
                    column: 19
                ),
            ]
        )
    }

    @Test func positionalFieldOutOfRange() {
        assertExpansion(
            """
            @Describable
            enum Value {
                @Description("Value {2}")
                case value(Int)
            }
            """,
            expandedSource: """
            enum Value {
                case value(Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "description field '{2}' does not exist; case 'value' has 1 associated value",
                    line: 3,
                    column: 25
                ),
            ]
        )
    }

    @Test func templateSyntaxErrors() {
        assertExpansion(
            """
            @Describable
            enum Value {
                @Description("a } {b.c()} {x:2} {")
                case value(x: Int)
            }
            """,
            expandedSource: """
            enum Value {
                case value(x: Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unmatched '}' in description template; use '}}' for a literal '}'",
                    line: 3,
                    column: 21,
                    fixIts: [FixItSpec(message: "use '}}' for a literal '}'")]
                ),
                DiagnosticSpec(
                    message: "'{b.c()}' is not supported in a description template; placeholders may use member paths, '?.', '?? literal' and '{path?}', and raw templates accept any expression",
                    line: 3,
                    column: 23
                ),
                DiagnosticSpec(message: "format specifiers such as '{x:2}' are not supported in description templates", line: 3, column: 31),
                DiagnosticSpec(
                    message: "unterminated description placeholder; use '{{' for a literal '{'",
                    line: 3,
                    column: 37,
                    fixIts: [FixItSpec(message: "use '{{' for a literal '{'")]
                ),
            ]
        )
    }

    @Test func nonLiteralTemplate() {
        assertExpansion(
            """
            @Describable
            enum Value {
                @Description(template)
                case value
            }
            """,
            expandedSource: """
            enum Value {
                case value
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "description template must be a string literal", line: 3, column: 18),
            ]
        )
    }

    @Test func interpolatedTemplate() {
        assertExpansion(
            #"""
            @Describable
            enum Value {
                @Description("v=\(x)")
                case value(x: Int)
            }
            """#,
            expandedSource: """
            enum Value {
                case value(x: Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "string interpolation is not supported in description templates; use '{name}' placeholders instead",
                    line: 3,
                    column: 21
                ),
            ]
        )
    }

    @Test func multilineTemplate() {
        assertExpansion(
            #"""
            @Describable
            enum Value {
                @Description("""
                    value
                    """)
                case value
            }
            """#,
            expandedSource: """
            enum Value {
                case value
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "multi-line string literals are not supported as description templates", line: 3, column: 18),
            ]
        )
    }

    @Test func templateOnEnumIsRejected() {
        assertExpansion(
            """
            @Describable("State")
            enum State {
                case idle
            }
            """,
            expandedSource: """
            enum State {
                case idle
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable does not accept templates when applied to an enum; annotate individual cases with @Description instead",
                    line: 1,
                    column: 14,
                    fixIts: [FixItSpec(message: "remove the template arguments")]
                ),
            ]
        )
    }

    @Test func duplicateDescription() {
        assertExpansion(
            """
            @Describable
            enum State {
                @Description("a")
                @Description("b")
                case idle
            }
            """,
            expandedSource: """
            enum State {
                case idle
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "description is already configured for this declaration",
                    line: 4,
                    column: 5,
                    fixIts: [FixItSpec(message: "remove the duplicate @Description")]
                ),
            ]
        )
    }

    @Test func descriptionWithoutArguments() {
        assertExpansion(
            """
            enum State {
                @Description
                case idle
            }
            """,
            expandedSource: """
            enum State {
                case idle
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Description requires a description template, an 'error' template, or both", line: 2, column: 5),
            ]
        )
    }

    @Test func descriptionOutsideEnumCase() {
        assertExpansion(
            """
            struct User {
                @Description("name")
                let name: String
            }
            """,
            expandedSource: """
            struct User {
                let name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@Description can only be applied to enum cases", line: 2, column: 5),
            ]
        )
    }

    @Test func descriptionWithoutDescribable() {
        assertExpansion(
            """
            enum State {
                @Description("Idle")
                case idle
            }
            """,
            expandedSource: """
            enum State {
                case idle
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Description has no effect unless the enclosing enum is annotated with @Describable",
                    line: 2,
                    column: 5,
                    severity: .warning
                ),
            ]
        )
    }

    @Test func functionIsUnsupported() {
        assertExpansion(
            """
            @Describable
            func foo() {}
            """,
            expandedSource: """
            func foo() {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable can only be applied to enum, struct, class, or actor declarations",
                    line: 1,
                    column: 1
                ),
            ]
        )
    }

    @Test func protocolIsUnsupported() {
        assertExpansion(
            """
            @Describable
            protocol Named {}
            """,
            expandedSource: """
            protocol Named {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable can only be applied to enum, struct, class, or actor declarations",
                    line: 1,
                    column: 1
                ),
            ]
        )
    }
}
