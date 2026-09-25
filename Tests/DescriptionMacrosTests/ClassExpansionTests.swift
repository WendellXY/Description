import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Class expansion")
struct ClassExpansionTests {
    @Test func finalClass() {
        assertExpansion(
            """
            @Describable
            @Description("Connection(host: {host}, port: {port})")
            final class Connection {
                let host: String
                var port: Int
            }
            """,
            expandedSource: """
            final class Connection {
                let host: String
                var port: Int
            }

            extension Connection: CustomStringConvertible {
                var description: String {
                    "Connection(host: \\(host), port: \\(port))"
                }
            }
            """
        )
    }

    @Test func openClassGetsPublicWitness() {
        assertExpansion(
            """
            @Describable
            @Description("Client(host: {host})")
            open class Client {
                public let host: String
            }
            """,
            expandedSource: """
            open class Client {
                public let host: String
            }

            extension Client: CustomStringConvertible {
                public var description: String {
                    "Client(host: \\(host))"
                }
            }
            """
        )
    }

    @Test func inheritedMembersAreNotVisible() {
        assertExpansion(
            """
            @Describable
            @Description("id={id}")
            class Child: Base {}
            """,
            expandedSource: """
            class Child: Base {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unknown description field 'id'; class 'Child' has no fields that can be used in a description",
                    line: 2,
                    column: 18,
                    notes: [
                        NoteSpec(
                            message: "@Describable only sees properties declared in the body of 'Child'; inherited properties cannot be used",
                            line: 3,
                            column: 14
                        ),
                    ]
                ),
            ]
        )
    }

    @Test func missingTemplate() {
        assertExpansion(
            """
            @Describable
            class Client {}
            """,
            expandedSource: """
            class Client {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable requires a description template when applied to a class",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: "add @Description(\"Client()\")")]
                ),
            ]
        )
    }
}
