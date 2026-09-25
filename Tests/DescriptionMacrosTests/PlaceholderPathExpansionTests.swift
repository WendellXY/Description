import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Placeholder paths")
struct PlaceholderPathExpansionTests {
    @Test func enumPathsDefaultsAndPresence() {
        assertExpansion(
            ##"""
            @Describable
            enum Route {
                @Description("grab(id: {info.redPacketId}, count: {rewards.count})")
                case grab(info: RedPacketInfo, rewards: [Reward])

                @Description("level(uid: {notify?.uid ?? 0}, name: {notify?.name})")
                case level(notify: Notify?)

                @Description(#"web(gameId: {config.gameId ?? "nil"}, resume: {state.resumeData?})"#)
                case web(config: GameConfig, state: GameState)
            }
            """##,
            expandedSource: ##"""
            enum Route {
                case grab(info: RedPacketInfo, rewards: [Reward])
                case level(notify: Notify?)
                case web(config: GameConfig, state: GameState)
            }

            extension Route: CustomStringConvertible {
                var description: String {
                    switch self {
                    case let .grab(info, rewards):
                        return "grab(id: \(String(describing: info.redPacketId)), count: \(String(describing: rewards.count)))"
                    case let .level(notify):
                        return "level(uid: \(notify?.uid ?? 0), name: \(String(describing: notify?.name)))"
                    case let .web(config, state):
                        return #"web(gameId: \#(config.gameId ?? "nil"), resume: \#(state.resumeData != nil))"#
                    }
                }
            }
            """##
        )
    }

    @Test func escapedStringDefaultInOrdinaryLiteral() {
        assertExpansion(
            #"""
            @Describable
            @Description("Game(id: {config.gameId ?? \"nil\"})")
            struct Game {
                let config: GameConfig
            }
            """#,
            expandedSource: #"""
            struct Game {
                let config: GameConfig
            }

            extension Game: CustomStringConvertible {
                var description: String {
                    "Game(id: \(config.gameId ?? "nil"))"
                }
            }
            """#
        )
    }

    @Test func misspelledRootKeepsTheRestOfThePath() {
        assertExpansion(
            """
            @Describable
            enum Route {
                @Description("{notfy?.uid ?? 0}")
                case level(notify: Notify?)
            }
            """,
            expandedSource: """
            enum Route {
                case level(notify: Notify?)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unknown description field 'notfy'; available fields: {notify}",
                    line: 3,
                    column: 19,
                    fixIts: [FixItSpec(message: "replace '{notfy}' with '{notify}'")]
                ),
            ],
            applyFixIts: ["replace '{notfy}' with '{notify}'"],
            fixedSource: """
            @Describable
            enum Route {
                @Description("{notify?.uid ?? 0}")
                case level(notify: Notify?)
            }
            """
        )
    }

    @Test func actorIsolationIsCheckedOnTheRoot() {
        assertExpansion(
            """
            @Describable
            @Description("{jobs.count}")
            actor Worker {
                var jobs: [Int]
            }
            """,
            expandedSource: """
            actor Worker {
                var jobs: [Int]
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'{jobs}' refers to actor-isolated state and cannot be used in a synchronous description",
                    line: 2,
                    column: 15,
                    notes: [
                        NoteSpec(
                            message: "'jobs' is isolated to the actor; only 'nonisolated' properties and 'let' constants can be read synchronously",
                            line: 4,
                            column: 5
                        ),
                    ]
                ),
            ]
        )
    }

    @Test func nonLiteralDefaultIsRejected() {
        assertExpansion(
            """
            @Describable
            enum Route {
                @Description("{uid ?? fallback}")
                case user(uid: Int?)
            }
            """,
            expandedSource: """
            enum Route {
                case user(uid: Int?)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "the default after '??' must be a literal such as 0, \"nil\", true or nil, not 'fallback'",
                    line: 3,
                    column: 19
                ),
            ]
        )
    }
}
