import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Actor expansion")
struct ActorExpansionTests {
    @Test func nonisolatedAndConstantProperties() {
        assertExpansion(
            """
            @Describable("Worker(id: {id}, name: {name}, label: {label})")
            public actor Worker {
                nonisolated let id: UUID
                let name: String
                nonisolated var label: String { "worker" }
                var pendingJobs: Int
            }
            """,
            expandedSource: """
            public actor Worker {
                nonisolated let id: UUID
                let name: String
                nonisolated var label: String { "worker" }
                var pendingJobs: Int
            }

            extension Worker: CustomStringConvertible {
                public nonisolated var description: String {
                    "Worker(id: \\(id), name: \\(name), label: \\(label))"
                }
            }
            """
        )
    }

    @Test func errorActorMembersAreNonisolated() {
        assertExpansion(
            """
            @Describable("Failure({code})", error: "Failed with {code}")
            actor Failure: Error {
                let code: Int
            }
            """,
            expandedSource: """
            actor Failure: Error {
                let code: Int
            }

            extension Failure: CustomStringConvertible, _DescribableLocalizedError {
                nonisolated var description: String {
                    "Failure(\\(code))"
                }

                nonisolated var errorDescription: String? {
                    "Failed with \\(code)"
                }
            }
            """
        )
    }

    @Test func isolatedMutablePropertyIsRejected() {
        assertExpansion(
            """
            @Describable("Worker(jobs: {jobs})")
            actor Worker {
                var jobs: [Job]
            }
            """,
            expandedSource: """
            actor Worker {
                var jobs: [Job]
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'{jobs}' refers to actor-isolated state and cannot be used in a synchronous description",
                    line: 1,
                    column: 28,
                    notes: [
                        NoteSpec(
                            message: "'jobs' is isolated to the actor; only 'nonisolated' properties and 'let' constants can be read synchronously",
                            line: 3,
                            column: 5
                        ),
                    ]
                ),
            ]
        )
    }

    @Test func isolatedComputedPropertyIsRejected() {
        assertExpansion(
            """
            @Describable("{count}")
            actor Counter {
                var count: Int { 0 }
            }
            """,
            expandedSource: """
            actor Counter {
                var count: Int { 0 }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'{count}' refers to actor-isolated state and cannot be used in a synchronous description",
                    line: 1,
                    column: 15,
                    notes: [
                        NoteSpec(
                            message: "'count' is isolated to the actor; only 'nonisolated' properties and 'let' constants can be read synchronously",
                            line: 3,
                            column: 5
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
            actor Worker {}
            """,
            expandedSource: """
            actor Worker {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable requires a description template when applied to an actor",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: "add template \"Worker()\"")]
                ),
            ]
        )
    }
}
