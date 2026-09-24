@testable import DescriptionMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Fix-its")
struct FixItTests {
    @Test func misspelledFieldIsCorrected() {
        assertExpansion(
            """
            @Describable
            enum State {
                @Description("Loading {resorce}!")
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
            ],
            applyFixIts: ["replace '{resorce}' with '{resource}'"],
            fixedSource: """
            @Describable
            enum State {
                @Description("Loading {resource}!")
                case loading(resource: String)
            }
            """
        )
    }

    @Test func misspelledPropertyIsCorrected() {
        assertExpansion(
            """
            @Describable("User({nmae})")
            struct User {
                let name: String
            }
            """,
            expandedSource: """
            struct User {
                let name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unknown description field 'nmae'; available fields: {name}",
                    line: 1,
                    column: 20,
                    fixIts: [FixItSpec(message: "replace '{nmae}' with '{name}'")]
                ),
            ],
            applyFixIts: ["replace '{nmae}' with '{name}'"],
            fixedSource: """
            @Describable("User({name})")
            struct User {
                let name: String
            }
            """
        )
    }

    @Test func distantNamesGetNoSuggestion() {
        assertExpansion(
            """
            @Describable("{identifier}")
            struct User {
                let name: String
            }
            """,
            expandedSource: """
            struct User {
                let name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "unknown description field 'identifier'; available fields: {name}", line: 1, column: 15),
            ]
        )
    }

    @Test func strayBracesAreEscaped() {
        assertExpansion(
            """
            @Describable("Object { id: {id} }")
            struct Object {
                let id: Int
            }
            """,
            expandedSource: """
            struct Object {
                let id: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unterminated description placeholder; use '{{' for a literal '{'",
                    line: 1,
                    column: 22,
                    fixIts: [FixItSpec(message: "use '{{' for a literal '{'")]
                ),
                DiagnosticSpec(
                    message: "unmatched '}' in description template; use '}}' for a literal '}'",
                    line: 1,
                    column: 33,
                    fixIts: [FixItSpec(message: "use '}}' for a literal '}'")]
                ),
            ],
            applyFixIts: ["use '{{' for a literal '{'"],
            fixedSource: """
            @Describable("Object {{ id: {id} }")
            struct Object {
                let id: Int
            }
            """
        )
    }

    @Test func missingTemplateIsFilledWithStoredProperties() {
        assertExpansion(
            """
            @Describable
            struct User {
                let id: UUID
                var name: String
                var initials: String { "" }
                static let anonymous = 0
            }
            """,
            expandedSource: """
            struct User {
                let id: UUID
                var name: String
                var initials: String { "" }
                static let anonymous = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable requires a description template when applied to a struct",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: #"add template "User(id: {id}, name: {name})""#)]
                ),
            ],
            applyFixIts: [#"add template "User(id: {id}, name: {name})""#],
            fixedSource: """
            @Describable("User(id: {id}, name: {name})")
            struct User {
                let id: UUID
                var name: String
                var initials: String { "" }
                static let anonymous = 0
            }
            """
        )
    }

    @Test func missingTemplateKeepsErrorArgumentAndSkipsIsolatedState() {
        assertExpansion(
            """
            @Describable(error: "failed")
            actor Worker: Error {
                nonisolated let id: Int
                var jobs: [Int]
            }
            """,
            expandedSource: """
            actor Worker: Error {
                nonisolated let id: Int
                var jobs: [Int]
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable requires a description template when applied to an actor",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: #"add template "Worker(id: {id})""#)]
                ),
            ],
            applyFixIts: [#"add template "Worker(id: {id})""#],
            fixedSource: """
            @Describable("Worker(id: {id})", error: "failed")
            actor Worker: Error {
                nonisolated let id: Int
                var jobs: [Int]
            }
            """
        )
    }

    @Test func enumTemplateArgumentsAreRemoved() {
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
            ],
            applyFixIts: ["remove the template arguments"],
            fixedSource: """
            @Describable
            enum State {
                case idle
            }
            """
        )
    }

    @Test func duplicateDescriptionIsRemoved() {
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
            ],
            applyFixIts: ["remove the duplicate @Description"],
            fixedSource: """
            @Describable
            enum State {
                @Description("a")
                case idle
            }
            """
        )
    }

    @Test(arguments: [
        ("struct User {", "struct User: Error {"),
        ("struct User<T> {", "struct User<T>: Error {"),
        ("struct User: Sendable {", "struct User: Sendable, Error {"),
        ("struct User: Sendable, Hashable {", "struct User: Sendable, Hashable, Error {"),
        ("final class User {", "final class User: Error {"),
    ])
    func errorConformanceIsAdded(header: String, fixedHeader: String) {
        assertExpansion(
            """
            @Describable("User", error: "Invalid user")
            \(header)
            }
            """,
            expandedSource: """
            \(header)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'error' is only available for types conforming to Error",
                    line: 1,
                    column: 22,
                    notes: [
                        NoteSpec(
                            message: "@Describable only detects 'Error' in the inheritance clause of 'User'; conformances declared in extensions are not detected",
                            line: 2,
                            column: header.hasPrefix("final") ? 13 : 8
                        ),
                    ],
                    fixIts: [FixItSpec(message: "add 'Error' conformance")]
                ),
            ],
            applyFixIts: ["add 'Error' conformance"],
            fixedSource: """
            @Describable("User", error: "Invalid user")
            \(fixedHeader)
            }
            """
        )
    }

    @Test func errorConformanceIsAddedToEnum() {
        assertExpansion(
            """
            @Describable
            enum State {
                @Description(error: "Something failed")
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
                    message: "'error' is only available for types conforming to Error",
                    line: 3,
                    column: 18,
                    notes: [
                        NoteSpec(
                            message: "@Describable only detects 'Error' in the inheritance clause of 'State'; conformances declared in extensions are not detected",
                            line: 2,
                            column: 6
                        ),
                    ],
                    fixIts: [FixItSpec(message: "add 'Error' conformance")]
                ),
            ],
            applyFixIts: ["add 'Error' conformance"],
            fixedSource: """
            @Describable
            enum State: Error {
                @Description(error: "Something failed")
                case idle
            }
            """
        )
    }

    @Test func editDistance() {
        #expect(SpellingSuggestion.editDistance("resorce", "resource") == 1)
        #expect(SpellingSuggestion.editDistance("", "abc") == 3)
        #expect(SpellingSuggestion.editDistance("kitten", "sitting") == 3)
        #expect(SpellingSuggestion.closest(to: "nmae", in: ["name", "id"]) == "name")
        #expect(SpellingSuggestion.closest(to: "ab", in: ["ac", "ad"]) == nil)
        #expect(SpellingSuggestion.closest(to: "identifier", in: ["name"]) == nil)
    }
}
