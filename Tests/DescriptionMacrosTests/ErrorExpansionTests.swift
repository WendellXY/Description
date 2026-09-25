import SwiftSyntaxMacrosGenericTestSupport
import Testing

@Suite("Error expansion")
struct ErrorExpansionTests {
    @Test func enumErrorForwardsToDescription() {
        assertExpansion(
            """
            @Describable
            enum NetworkError: Error {
                @Description("Request failed: {underlying}")
                case requestFailed(underlying: any Error)

                case unavailable
            }
            """,
            expandedSource: """
            enum NetworkError: Error {
                case requestFailed(underlying: any Error)

                case unavailable
            }

            extension NetworkError: CustomStringConvertible, _DescribableLocalizedError {
                var description: String {
                    switch self {
                    case let .requestFailed(underlying):
                        return "Request failed: \\(underlying)"
                    case .unavailable:
                        return "unavailable"
                    }
                }

                var errorDescription: String? {
                    description
                }
            }
            """
        )
    }

    @Test func enumCasesWithErrorTemplates() {
        assertExpansion(
            """
            @Describable
            enum HTTPError: Swift.Error {
                @Description("invalidStatus(code: {code})")
                @Description(.error, "The server returned HTTP {code}.")
                case invalidStatus(code: Int)

                @Description(.error, "HTTP request failed with code {0}.")
                case failed(Int)

                case unavailable
            }
            """,
            expandedSource: """
            enum HTTPError: Swift.Error {
                case invalidStatus(code: Int)
                case failed(Int)

                case unavailable
            }

            extension HTTPError: CustomStringConvertible, _DescribableLocalizedError {
                var description: String {
                    switch self {
                    case let .invalidStatus(code):
                        return "invalidStatus(code: \\(code))"
                    case .failed:
                        return "failed"
                    case .unavailable:
                        return "unavailable"
                    }
                }

                var errorDescription: String? {
                    switch self {
                    case let .invalidStatus(code):
                        return "The server returned HTTP \\(code)."
                    case let .failed(_0):
                        return "HTTP request failed with code \\(_0)."
                    case .unavailable:
                        return "unavailable"
                    }
                }
            }
            """
        )
    }

    @Test func structWithErrorTemplate() {
        assertExpansion(
            """
            @Describable
            @Description("HTTPError(code: {code}, endpoint: {endpoint})")
            @Description(.error, "The request failed with HTTP {code}.")
            public struct HTTPError: Error {
                let code: Int
                let endpoint: URL
            }
            """,
            expandedSource: """
            public struct HTTPError: Error {
                let code: Int
                let endpoint: URL
            }

            extension HTTPError: CustomStringConvertible, _DescribableLocalizedError {
                public var description: String {
                    "HTTPError(code: \\(code), endpoint: \\(endpoint))"
                }

                public var errorDescription: String? {
                    "The request failed with HTTP \\(code)."
                }
            }
            """
        )
    }

    @Test func structErrorWithoutErrorTemplate() {
        assertExpansion(
            """
            @Describable
            @Description("HTTPError(code: {code})")
            struct HTTPError: Error {
                let code: Int
            }
            """,
            expandedSource: """
            struct HTTPError: Error {
                let code: Int
            }

            extension HTTPError: CustomStringConvertible, _DescribableLocalizedError {
                var description: String {
                    "HTTPError(code: \\(code))"
                }

                var errorDescription: String? {
                    description
                }
            }
            """
        )
    }

    @Test func conformanceInExtensionIsNotDetected() {
        assertExpansion(
            """
            @Describable
            enum Foo {
                case bar
            }

            extension Foo: Error {}
            """,
            expandedSource: """
            enum Foo {
                case bar
            }

            extension Foo: Error {}

            extension Foo: CustomStringConvertible {
                var description: String {
                    switch self {
                    case .bar:
                        return "bar"
                    }
                }
            }
            """
        )
    }

    @Test func errorTemplateOnNonErrorStruct() {
        assertExpansion(
            """
            @Describable
            @Description("User(name: {name})")
            @Description(.error, "Invalid user")
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
                    message: "'.error' is only available for types conforming to Error",
                    line: 3,
                    column: 14,
                    notes: [
                        NoteSpec(
                            message: "@Describable only detects 'Error' in the inheritance clause of 'User'; conformances declared in extensions are not detected",
                            line: 4,
                            column: 8
                        ),
                    ],
                    fixIts: [FixItSpec(message: "add 'Error' conformance")]
                ),
            ]
        )
    }

    @Test func errorTemplateOnNonErrorEnumCase() {
        assertExpansion(
            """
            @Describable
            enum State {
                @Description(.error, "Something failed")
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
            ]
        )
    }

    @Test func errorOnlyTemplateStillRequiresDescriptionForStructs() {
        assertExpansion(
            """
            @Describable
            @Description(.error, "failed")
            struct Failure: Error {}
            """,
            expandedSource: """
            struct Failure: Error {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@Describable requires a description template when applied to a struct",
                    line: 1,
                    column: 1,
                    fixIts: [FixItSpec(message: "add @Description(\"Failure()\")")]
                ),
            ]
        )
    }

    @Test func errorTemplatePlaceholdersAreValidated() {
        assertExpansion(
            """
            @Describable
            enum Failure: Error {
                @Description(.error, "code {cdoe}")
                case status(code: Int)
            }
            """,
            expandedSource: """
            enum Failure: Error {
                case status(code: Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "unknown description field 'cdoe'; available fields: {code}",
                    line: 3,
                    column: 32,
                    fixIts: [FixItSpec(message: "replace '{cdoe}' with '{code}'")]
                ),
            ]
        )
    }
}
