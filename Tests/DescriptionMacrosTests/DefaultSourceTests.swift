import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Default sources")
struct DefaultSourceTests {
    @Test func rawValueWithoutOverridesNeedsNoSwitch() {
        assertExpansion(
            """
            @Describable(default: .rawValue)
            enum PayErrorCode: Int, Error {
                case timeout = 1016
                case denied = 1017
            }
            """,
            expandedSource: #"""
            enum PayErrorCode: Int, Error {
                case timeout = 1016
                case denied = 1017
            }

            extension PayErrorCode: CustomStringConvertible, _DescribableLocalizedError {
                var description: String {
                    "\(rawValue)"
                }

                var errorDescription: String? {
                    description
                }
            }
            """#
        )
    }

    @Test func casesCanOverrideTheDefault() {
        assertExpansion(
            """
            @Describable(default: .member("title"))
            enum Tab {
                case chat
                @Description("home!")
                case home

                var title: String { "" }
            }
            """,
            expandedSource: #"""
            enum Tab {
                case chat
                case home

                var title: String { "" }
            }

            extension Tab: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .chat:
                        return "\(title)"
                    case .home:
                        return "home!"
                    }
                }
            }
            """#
        )
    }

    @Test func structsCanUseAMemberInsteadOfATemplate() {
        assertExpansion(
            """
            @Describable(default: .member("name"))
            struct Tag {
                let name: String
            }
            """,
            expandedSource: #"""
            struct Tag {
                let name: String
            }

            extension Tag: CustomStringConvertible {
                var description: String {
                    "\(name)"
                }
            }
            """#
        )
    }

    @Test func invalidSource() {
        assertExpansion(
            """
            @Describable(default: .title)
            enum Tab {
                case chat
            }
            """,
            expandedSource: """
            enum Tab {
                case chat
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: #"default must be .caseName, .rawValue, or .member("name")"#, line: 1, column: 23),
            ]
        )
    }

    @Test func caseNameIsNotAvailableForStructs() {
        assertExpansion(
            """
            @Describable(default: .caseName)
            struct Tag {
                let name: String
            }
            """,
            expandedSource: """
            struct Tag {
                let name: String
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable requires a description template when applied to a struct",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: #"add @Description("Tag(name: {name})")"#)]
                ),
            ]
        )
    }
}
