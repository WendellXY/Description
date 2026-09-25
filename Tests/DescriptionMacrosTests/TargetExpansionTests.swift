import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Description targets")
struct TargetExpansionTests {
    @Test func debugOnlyEnum() {
        assertExpansion(
            """
            @Describable(generating: [.debug])
            enum TabIndex: Int {
                @Description(.debug, "Main.MainTabBar.Tab.Chat")
                case chat
                case home
            }
            """,
            expandedSource: """
            enum TabIndex: Int {
                case chat
                case home
            }

            extension TabIndex: CustomDebugStringConvertible {
                var debugDescription: String {
                    switch self {
                    case .chat:
                        return "Main.MainTabBar.Tab.Chat"
                    case .home:
                        return "home"
                    }
                }
            }
            """
        )
    }

    @Test func everyTargetOnOneCase() {
        assertExpansion(
            """
            @Describable
            enum LoadError: Error {
                @Description("loadFailed({0})")
                @Description(.error, "Could not load {0}.")
                @Description(.debug, "LoadError.loadFailed({0})")
                @Description("analyticsName", "load_failed")
                case loadFailed(URL)

                case cancelled
            }
            """,
            expandedSource: """
            enum LoadError: Error {
                case loadFailed(URL)

                case cancelled
            }

            extension LoadError: CustomStringConvertible, CustomDebugStringConvertible, _DescribableLocalizedError {
                var description: String {
                    switch self {
                    case let .loadFailed(_0):
                        return "loadFailed(\\(_0))"
                    case .cancelled:
                        return "cancelled"
                    }
                }

                var debugDescription: String {
                    switch self {
                    case let .loadFailed(_0):
                        return "LoadError.loadFailed(\\(_0))"
                    case .cancelled:
                        return "cancelled"
                    }
                }

                var errorDescription: String? {
                    switch self {
                    case let .loadFailed(_0):
                        return "Could not load \\(_0)."
                    case .cancelled:
                        return "cancelled"
                    }
                }

                var analyticsName: String {
                    switch self {
                    case .loadFailed:
                        return "load_failed"
                    case .cancelled:
                        return "cancelled"
                    }
                }
            }
            """
        )
    }

    @Test func enumLevelTemplatesAreTheFallbackForCases() {
        assertExpansion(
            """
            @Describable
            @Description(.debug, "Tab.{title}")
            enum Tab {
                @Description(.debug, "Tab.chat!")
                case chat
                case home

                var title: String { "" }
            }
            """,
            expandedSource: """
            enum Tab {
                case chat
                case home

                var title: String { "" }
            }

            extension Tab: CustomStringConvertible, CustomDebugStringConvertible {
                var description: String {
                    switch self {
                    case .chat:
                        return "chat"
                    case .home:
                        return "home"
                    }
                }

                var debugDescription: String {
                    switch self {
                    case .chat:
                        return "Tab.chat!"
                    case .home:
                        return "Tab.\\(title)"
                    }
                }
            }
            """
        )
    }

    @Test func structTargetsForwardToDescriptionWithoutTheirOwnText() {
        assertExpansion(
            """
            @Describable(generating: [.description, .debug])
            @Description("User({name})")
            public struct User: Error {
                let id: Int
                let name: String
            }
            """,
            expandedSource: """
            public struct User: Error {
                let id: Int
                let name: String
            }

            extension User: CustomStringConvertible, CustomDebugStringConvertible {
                public var description: String {
                    "User(\\(name))"
                }

                public var debugDescription: String {
                    description
                }
            }
            """
        )
    }

    @Test func debugOnlyStructNeedsNoMainText() {
        assertExpansion(
            """
            @Describable(generating: [.debug])
            @Description(.debug, "User(id: {id})")
            struct User {
                let id: Int
            }
            """,
            expandedSource: """
            struct User {
                let id: Int
            }

            extension User: CustomDebugStringConvertible {
                var debugDescription: String {
                    "User(id: \\(id))"
                }
            }
            """
        )
    }

    @Test func customPropertyOnlyAddsNoConformance() {
        assertExpansion(
            """
            @Describable(generating: [.property("analyticsName")])
            @Description(.property("analyticsName"), "screen_{name}")
            actor Screen: AnalyticsNaming {
                nonisolated let name: String
            }
            """,
            expandedSource: """
            actor Screen: AnalyticsNaming {
                nonisolated let name: String
            }

            extension Screen {
                nonisolated var analyticsName: String {
                    "screen_\\(name)"
                }
            }
            """
        )
    }

    @Test func invalidTarget() {
        assertExpansion(
            """
            @Describable
            @Description("User")
            @Description(.verbose, "User!")
            struct User {}
            """,
            expandedSource: """
            struct User {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "description target must be .description, .error, .debug, .property(\"name\"), or a string literal naming a property",
                    line: 3,
                    column: 14
                ),
            ]
        )
    }

    @Test func duplicateTarget() {
        assertExpansion(
            """
            @Describable
            enum Failure: Error {
                @Description(.error, "a")
                @Description(.error, "b")
                case timeout
            }
            """,
            expandedSource: """
            enum Failure: Error {
                case timeout
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'.error' description is already configured for this declaration",
                    line: 4,
                    column: 5,
                    fixIts: [FixItSpec(message: "remove the duplicate @Description")]
                ),
            ]
        )
    }

    @Test func generatingErrorRequiresError() {
        assertExpansion(
            """
            @Describable(generating: [.description, .error])
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
                    message: "'.error' is only available for types conforming to Error",
                    line: 1,
                    column: 41,
                    notes: [
                        NoteSpec(
                            message: "@Describable only detects 'Error' in the inheritance clause of 'State'; conformances declared in extensions are not detected",
                            line: 2,
                            column: 6
                        ),
                    ],
                    fixIts: [FixItSpec(message: "add 'Error' conformance")]
                ),
            ]
        )
    }

    @Test func existingDebugConformanceAndCustomMember() {
        assertExpansion(
            """
            @Describable
            @Description(.debug, "Box")
            @Description("analyticsName", "box")
            struct Box: CustomDebugStringConvertible {
                var analyticsName: String { "manual" }
            }
            """,
            expandedSource: """
            struct Box: CustomDebugStringConvertible {
                var analyticsName: String { "manual" }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable requires a description template when applied to a struct",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: #"add @Description("Box()")"#)]
                ),
                DiagnosticSpec(
                    message: "'Box' already declares a conformance to 'CustomDebugStringConvertible'; @Describable cannot synthesize a conformance that already exists",
                    line: 4,
                    column: 13,
                    fixIts: [FixItSpec(message: "remove 'CustomDebugStringConvertible' conformance")]
                ),
                DiagnosticSpec(
                    message: "'analyticsName' is already implemented; @Describable cannot generate it",
                    line: 5,
                    column: 5
                ),
            ],
            conformances: ["CustomStringConvertible", "LocalizedError"]
        )
    }

    @Test func descriptionOnAPropertyIsMisplaced() {
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
                DiagnosticSpec(
                    message: "@Description can only be applied to enum, struct, class, or actor declarations and enum cases",
                    line: 2,
                    column: 5
                ),
            ]
        )
    }

    @Test func descriptionOnATypeWithoutDescribable() {
        assertExpansion(
            """
            @Description("User")
            struct User {}
            """,
            expandedSource: """
            struct User {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Description has no effect unless the type is annotated with @Describable",
                    line: 1,
                    column: 1,
                    severity: .warning
                ),
            ]
        )
    }
}
