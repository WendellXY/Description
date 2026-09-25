import Description
import Testing

@Describable
enum NetworkError: Error {
    @Description("Request failed: {underlying}")
    case requestFailed(underlying: any Error)

    case unavailable
}

@Describable
enum HTTPStatusError: Error {
    @Description("invalidStatus(code: {code})", error: "The server returned HTTP {code}.")
    case invalidStatus(code: Int)

    @Description(error: "Timed out after {0}s.")
    case timeout(Int)

    case unavailable
}

@Describable("HTTPError(code: {code})", error: "HTTP request failed with code {code}.")
struct HTTPError: Error {
    let code: Int
}

@Describable("PlainError(code: {code})")
public struct PlainError: Swift.Error {
    let code: Int
}

@Describable("ValidationError(field: {field})")
final class ValidationError: Error {
    let field: String

    init(field: String) {
        self.field = field
    }
}

private struct Underlying: Error, CustomStringConvertible {
    var description: String { "boom" }
}

@Suite("Error descriptions")
struct ErrorDescriptionTests {
    @Test func enumErrorDescriptionDefaultsToDescription() {
        let failed = NetworkError.requestFailed(underlying: Underlying())
        #expect(failed.description == "Request failed: boom")
        #expect(failed.errorDescription == "Request failed: boom")
        #expect(NetworkError.unavailable.description == "unavailable")
        #expect(NetworkError.unavailable.errorDescription == "unavailable")
    }

    @Test func enumCasesCanHaveDistinctErrorDescriptions() {
        #expect(HTTPStatusError.invalidStatus(code: 500).description == "invalidStatus(code: 500)")
        #expect(HTTPStatusError.invalidStatus(code: 500).errorDescription == "The server returned HTTP 500.")
        #expect(HTTPStatusError.timeout(30).description == "timeout")
        #expect(HTTPStatusError.timeout(30).errorDescription == "Timed out after 30s.")
        #expect(HTTPStatusError.unavailable.errorDescription == "unavailable")
    }

    @Test func structErrorTemplate() {
        #expect(String(describing: HTTPError(code: 500)) == "HTTPError(code: 500)")
        #expect(HTTPError(code: 500).localizedDescription == "HTTP request failed with code 500.")
    }

    @Test func errorDescriptionDefaultsToDescription() {
        #expect(PlainError(code: 1).errorDescription == "PlainError(code: 1)")
        #expect(PlainError(code: 1).localizedDescription == "PlainError(code: 1)")
        #expect(ValidationError(field: "email").localizedDescription == "ValidationError(field: email)")
    }

    @Test func thrownErrorsBridgeLocalizedDescription() {
        func fail() throws { throw HTTPStatusError.invalidStatus(code: 404) }
        do {
            try fail()
            Issue.record("Expected fail() to throw")
        } catch {
            #expect(error.localizedDescription == "The server returned HTTP 404.")
        }
    }
}
