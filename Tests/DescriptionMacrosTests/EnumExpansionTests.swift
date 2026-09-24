import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Enum expansion")
struct EnumExpansionTests {
    @Test func simpleCasesUseCaseNames() {
        assertExpansion(
            """
            @Describable
            enum State {
                case idle
                case loading, complete
            }
            """,
            expandedSource: """
            enum State {
                case idle
                case loading, complete
            }

            extension State: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .idle:
                        return "idle"
                    case .loading:
                        return "loading"
                    case .complete:
                        return "complete"
                    }
                }
            }
            """
        )
    }

    @Test func emptyEnum() {
        assertExpansion(
            """
            @Describable
            enum Never2 {
            }
            """,
            expandedSource: """
            enum Never2 {
            }

            extension Never2: CustomStringConvertible {
                var description: String {
                    switch self {
                    }
                }
            }
            """
        )
    }

    @Test func associatedValuesAreIgnoredWithoutTemplate() {
        assertExpansion(
            """
            @Describable
            enum State {
                case loading(resource: String)
            }
            """,
            expandedSource: """
            enum State {
                case loading(resource: String)
            }

            extension State: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .loading:
                        return "loading"
                    }
                }
            }
            """
        )
    }

    @Test func namedPlaceholders() {
        assertExpansion(
            """
            @Describable
            enum State {
                case idle

                @Description("Loading {resource}")
                case loading(resource: String)

                @Description("Loaded {count} items")
                case loaded(count: Int)
            }
            """,
            expandedSource: """
            enum State {
                case idle
                case loading(resource: String)
                case loaded(count: Int)
            }

            extension State: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .idle:
                        return "idle"
                    case let .loading(resource):
                        return "Loading \\(resource)"
                    case let .loaded(count):
                        return "Loaded \\(count) items"
                    }
                }
            }
            """
        )
    }

    @Test func positionalPlaceholders() {
        assertExpansion(
            """
            @Describable
            enum Comparison {
                @Description("Expected {0}, got {1}")
                case mismatch(String, String)
            }
            """,
            expandedSource: """
            enum Comparison {
                case mismatch(String, String)
            }

            extension Comparison: CustomStringConvertible {
                var description: String {
                    switch self {
                    case let .mismatch(_0, _1):
                        return "Expected \\(_0), got \\(_1)"
                    }
                }
            }
            """
        )
    }

    @Test func unusedValuesAreWildcardsAndReusedValuesBindOnce() {
        assertExpansion(
            """
            @Describable
            enum Event {
                @Description("{name}={1}; again {name}")
                case pair(name: String, Int, flag: Bool)
            }
            """,
            expandedSource: """
            enum Event {
                case pair(name: String, Int, flag: Bool)
            }

            extension Event: CustomStringConvertible {
                var description: String {
                    switch self {
                    case let .pair(name, _1, _):
                        return "\\(name)=\\(_1); again \\(name)"
                    }
                }
            }
            """
        )
    }

    @Test func escapedBracesAndRawStrings() {
        assertExpansion(
            ##"""
            @Describable
            enum Shape {
                @Description("Object {{ id: {id} }}")
                case object(id: Int)

                @Description(#"path\{0}"#)
                case path(String)
            }
            """##,
            expandedSource: ##"""
            enum Shape {
                case object(id: Int)
                case path(String)
            }

            extension Shape: CustomStringConvertible {
                var description: String {
                    switch self {
                    case let .object(id):
                        return "Object { id: \(id) }"
                    case let .path(_0):
                        return #"path\\#(_0)"#
                    }
                }
            }
            """##
        )
    }

    @Test func optionalAssociatedValuesUseStringDescribing() {
        assertExpansion(
            """
            @Describable
            enum Lookup {
                @Description("found {0}")
                case found(String?)
            }
            """,
            expandedSource: """
            enum Lookup {
                case found(String?)
            }

            extension Lookup: CustomStringConvertible {
                var description: String {
                    switch self {
                    case let .found(_0):
                        return "found \\(String(describing: _0))"
                    }
                }
            }
            """
        )
    }

    @Test func keywordLabelsAndCaseNamesAreEscaped() {
        assertExpansion(
            """
            @Describable
            enum Option {
                case `default`

                @Description("in {in}")
                case scoped(in: String)
            }
            """,
            expandedSource: """
            enum Option {
                case `default`
                case scoped(in: String)
            }

            extension Option: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .`default`:
                        return "default"
                    case let .scoped(`in`):
                        return "in \\(`in`)"
                    }
                }
            }
            """
        )
    }

    @Test func conditionalCasesAreMirrored() {
        assertExpansion(
            """
            @Describable
            enum Mode {
                case release
                #if DEBUG
                case debug
                #elseif TESTING
                case testing
                #else
                #endif
            }
            """,
            expandedSource: """
            enum Mode {
                case release
                #if DEBUG
                case debug
                #elseif TESTING
                case testing
                #else
                #endif
            }

            extension Mode: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .release:
                        return "release"
                    #if DEBUG
                    case .debug:
                        return "debug"
                    #elseif TESTING
                    case .testing:
                        return "testing"
                    #else
                    #endif
                    }
                }
            }
            """
        )
    }

    @Test func publicEnumGetsPublicWitness() {
        assertExpansion(
            """
            @Describable
            public enum Direction {
                case north
            }
            """,
            expandedSource: """
            public enum Direction {
                case north
            }

            extension Direction: CustomStringConvertible {
                public var description: String {
                    switch self {
                    case .north:
                        return "north"
                    }
                }
            }
            """
        )
    }
}
