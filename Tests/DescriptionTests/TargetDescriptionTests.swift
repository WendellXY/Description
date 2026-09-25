import Description
import Foundation
import Testing

protocol AnalyticsNaming {
    var analyticsName: String { get }
}

@Describable(generating: [.debug])
enum TabIndex: Int {
    @Description(.debug, "Main.MainTabBar.Tab.Chat")
    case chat
    @Description(.debug, "Main.MainTabBar.Tab.Home")
    case home
}

@Describable
@Description("TargetUser({name})")
@Description(.debug, "TargetUser(id: {id}, name: {name})")
struct TargetUser {
    let id: Int
    let name: String
}

@Describable
@DescribableProperties
enum LoadError: Error, AnalyticsNaming {
    @Description("loadFailed({0})")
    @Description(.error, "Could not load {0}.")
    @Description("analyticsName", "load_failed")
    case loadFailed(String)

    case cancelled
}

@Describable
@DescribableProperties
@Description("Screen.chat")
@Description(.property("analyticsName"), "chat_{roomName}")
public struct ChatScreen: AnalyticsNaming {
    let roomName: String
}

@Suite("Description targets")
struct TargetDescriptionTests {
    @Test func debugOnly() {
        #expect(TabIndex.chat.debugDescription == "Main.MainTabBar.Tab.Chat")
        #expect(String(reflecting: TabIndex.home) == "Main.MainTabBar.Tab.Home")
        // No CustomStringConvertible: the default description is used.
        #expect(!((TabIndex.chat as Any) is CustomStringConvertible))
    }

    @Test func separateDescriptionAndDebugDescription() {
        let user = TargetUser(id: 1, name: "Ada")
        #expect(String(describing: user) == "TargetUser(Ada)")
        #expect(String(reflecting: user) == "TargetUser(id: 1, name: Ada)")
    }

    @Test func errorAndCustomTargets() {
        let error = LoadError.loadFailed("profile")
        #expect(error.description == "loadFailed(profile)")
        #expect(error.errorDescription == "Could not load profile.")
        #expect(error.analyticsName == "load_failed")
        #expect(LoadError.cancelled.analyticsName == "cancelled")
        #expect(LoadError.cancelled.errorDescription == "cancelled")
    }

    @Test func customProtocolWitness() {
        let screen: any AnalyticsNaming = ChatScreen(roomName: "lobby")
        #expect(screen.analyticsName == "chat_lobby")
        #expect(ChatScreen(roomName: "lobby").description == "Screen.chat")
    }
}

// Regression test (reported from lama-ludo-ios on 0.2.0): with
// `names: arbitrary` on @Describable, this enum failed to conform to
// Equatable because the compiler counted the hand-written == twice.
@Describable
public enum WithClosure: Hashable, Sendable {
    case moment(updatePageIndex: @Sendable (Int) -> Void)
    @Description("detail(topicId: {topicId})")
    case detail(topicId: Int64)

    public static func == (lhs: WithClosure, rhs: WithClosure) -> Bool {
        switch (lhs, rhs) {
        case (.moment, .moment): true
        case let (.detail(a), .detail(b)): a == b
        default: false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .moment: hasher.combine(0)
        case let .detail(id): hasher.combine(id)
        }
    }
}

@Suite("Closure payloads")
struct ClosurePayloadTests {
    @Test func handWrittenEquatableStillWorks() {
        #expect(WithClosure.detail(topicId: 1) == .detail(topicId: 1))
        #expect(WithClosure.detail(topicId: 7).description == "detail(topicId: 7)")
        #expect(WithClosure.moment(updatePageIndex: { _ in }).description == "moment")
    }
}
