import Description
import Testing

struct RawItem { let isActive: Bool }

@Describable
enum RawRoute {
    @Description(raw: #"web(id: {gameId ?? "nil"}, active: {items.filter { $0.isActive }.count})"#)
    case web(gameId: String?, items: [RawItem], flag: Bool)
}

@Suite("Raw templates")
struct RawTemplateDescriptionTests {
    @Test func closuresAndMemberChains() {
        let items = [RawItem(isActive: true), RawItem(isActive: false)]
        #expect(RawRoute.web(gameId: nil, items: items, flag: true).description == "web(id: nil, active: 1)")
    }
}
