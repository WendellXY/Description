import Description
import Testing

// Optionals reached through member paths, whose types the macro cannot see
// (reported from lama-ludo-ios). These must compile without the "debug
// description for an optional value" warning and print like interpolation.

struct StoreLocator { let storeType: String? }
struct TournamentInvitationData { let uid: Int?; let gameType: String? }

@Describable
enum StoreRoute {
    @Description(raw: #"GameStore(storeType: {locator.storeType})"#)
    case gameStore(_ locator: StoreLocator)

    @Description("tournamentInvitation(uid: {notify.uid ?? 0}, gameType: {notify.gameType})")
    case tournamentInvitation(notify: TournamentInvitationData)

    @Description(raw: "level({_0})")
    case level(Bool?)
}

@Suite("Optional member paths")
struct OptionalPathTests {
    @Test func printLikeInterpolation() {
        let storeType: String? = "gold"
        #expect(StoreRoute.gameStore(StoreLocator(storeType: storeType)).description == "GameStore(storeType: \(String(describing: storeType)))")
        #expect(
            StoreRoute.tournamentInvitation(notify: .init(uid: nil, gameType: nil)).description
                == "tournamentInvitation(uid: 0, gameType: nil)"
        )
        #expect(StoreRoute.level(true).description == "level(Optional(true))")
    }
}
