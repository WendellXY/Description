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
enum LoadError: Error, AnalyticsNaming {
    @Description("loadFailed({0})")
    @Description(.error, "Could not load {0}.")
    @Description("analyticsName", "load_failed")
    case loadFailed(String)

    case cancelled
}

@Describable
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
