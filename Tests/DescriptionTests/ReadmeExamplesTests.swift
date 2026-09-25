import Description
import Foundation
import Testing

// The examples from README.md, kept compiling.

@Describable
enum RequestState {
    case idle

    @Description("Loading {url}")
    case loading(url: URL)

    @Description("Received {bytes} bytes")
    case loaded(bytes: Int)
}

@Describable
enum ReadmeComparison {
    case equal

    @Description("Expected {0}, got {1}")
    case mismatch(String, String)
}

@Describable
@Description("Connection(host: {host}, port: {port})")
final class Connection {
    let host: String
    let port: Int

    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}

@Describable
@Description("HTTPError(code: {code}, endpoint: {endpoint})")
@Description(.error, "The request failed with HTTP {code}.")
struct ReadmeHTTPError: Error {
    let code: Int
    let endpoint: URL
}

@Describable
enum APIError: Error {
    @Description("invalidStatus(code: {code})")
    @Description(.error, "The server returned HTTP {code}.")
    case invalidStatus(code: Int)

    @Description(.error, "The request timed out after {0} seconds.")
    case timeout(Int)

    case unavailable
}

@Suite("README examples")
struct ReadmeExamplesTests {
    private let url = URL(string: "https://example.com/users")!

    @Test func enums() {
        #expect(RequestState.idle.description == "idle")
        #expect(RequestState.loaded(bytes: 42).description == "Received 42 bytes")
        #expect(RequestState.loading(url: url).description == "Loading https://example.com/users")
        #expect(ReadmeComparison.equal.description == "equal")
        #expect(ReadmeComparison.mismatch("a", "b").description == "Expected a, got b")
    }

    @Test func classes() {
        #expect(Connection(host: "localhost", port: 8080).description == "Connection(host: localhost, port: 8080)")
    }

    @Test func errors() {
        let error = ReadmeHTTPError(code: 500, endpoint: url)
        #expect(String(describing: error) == "HTTPError(code: 500, endpoint: https://example.com/users)")
        #expect(error.localizedDescription == "The request failed with HTTP 500.")
        #expect(APIError.timeout(30).description == "timeout")
        #expect(APIError.timeout(30).errorDescription == "The request timed out after 30 seconds.")
        #expect(APIError.invalidStatus(code: 503).errorDescription == "The server returned HTTP 503.")
        #expect(APIError.unavailable.errorDescription == "unavailable")
    }
}

// 0.2 README examples.

struct ReadmeGameConfig { let gameId: String? }
struct ReadmeGameState { let resumeGameData: [UInt8]? }
struct ReadmeItem { let isActive: Bool }

@Describable
enum ReadmeRoute: Error {
    @Description(#"webGame(gameId: {config.gameId ?? "nil"}, hasResumeData: {state.resumeGameData?})"#)
    case webGame(config: ReadmeGameConfig, state: ReadmeGameState)

    @Description(raw: #"cart(items: {items.filter { $0.isActive }.count}, total: {total.description})"#)
    case cart(items: [ReadmeItem], total: Double)

    @Description(.error, raw: #"{"game_info_lost".uppercased()}"#)
    case gameInfoLost
}

@Describable(default: .member("title"))
enum ReadmeTab {
    case chat, home
    var title: String { self == .chat ? "Chat" : "Home" }
}

protocol ReadmeAnalyticsNaming {
    var analyticsName: String { get }
}

@Describable
@DescribableProperties
enum ReadmeScreen: ReadmeAnalyticsNaming {
    @Description("analyticsName", "chat_room")
    case chat(roomId: Int)
    case home
}

@Suite("README 0.2 examples")
struct ReadmeTargetExamplesTests {
    @Test func placeholdersAndRawTemplates() {
        let route = ReadmeRoute.webGame(config: .init(gameId: nil), state: .init(resumeGameData: []))
        #expect(route.description == "webGame(gameId: nil, hasResumeData: true)")
        let cart = ReadmeRoute.cart(items: [.init(isActive: true), .init(isActive: false)], total: 2.5)
        #expect(cart.description == "cart(items: 1, total: 2.5)")
        #expect(ReadmeRoute.gameInfoLost.errorDescription == "GAME_INFO_LOST")
        #expect(ReadmeRoute.gameInfoLost.description == "gameInfoLost")
    }

    @Test func defaultsAndCustomProperties() {
        #expect(ReadmeTab.chat.description == "Chat")
        #expect(ReadmeScreen.chat(roomId: 1).analyticsName == "chat_room")
        #expect(ReadmeScreen.home.analyticsName == "home")
    }
}
