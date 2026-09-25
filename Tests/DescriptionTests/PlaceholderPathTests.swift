import Description
import Testing

// Shapes taken from lama-ludo-ios route enums, whose descriptions double as
// navigation IDs and must match the hand-written strings byte for byte.

struct RedPacketInfo { let redPacketId: Int64 }
struct RewardInfo {}
struct LevelUpgradeNotify { let uid: Int64; let crrLevel: Int }
struct GameConfig { let gameId: String? }
struct GameState { let resumeGameData: [UInt8]? }

@Describable
enum AppRoute {
    @Description("grabRedPacket(roomId: {roomId}, redPacketId: {info.redPacketId}, autoDismiss: {autoDismiss})")
    case grabRedPacket(roomId: Int64, info: RedPacketInfo, autoDismiss: Bool)

    @Description("rocketUserReward(level: {level}, rewardCount: {rewards.count})")
    case rocketUserReward(level: Int, rewards: [RewardInfo])

    @Description("levelUpgradeDialog(uid: {notify?.uid ?? 0}, level: {notify?.crrLevel ?? 0})")
    case levelUpgradeDialog(notify: LevelUpgradeNotify?)

    @Description(#"webGame(gameId: {config.gameId ?? "nil"}, hasResumeData: {state.resumeGameData?}, autoStartMatch: {autoStartMatch})"#)
    case webGame(config: GameConfig, state: GameState, autoStartMatch: Bool)
}

@Suite("Placeholder paths")
struct PlaceholderPathTests {
    @Test func matchesHandWrittenStrings() {
        let info = RedPacketInfo(redPacketId: 9)
        #expect(
            AppRoute.grabRedPacket(roomId: 1, info: info, autoDismiss: true).description
                == "grabRedPacket(roomId: \(1), redPacketId: \(info.redPacketId), autoDismiss: \(true))"
        )
        let rewards = [RewardInfo(), RewardInfo()]
        #expect(
            AppRoute.rocketUserReward(level: 3, rewards: rewards).description
                == "rocketUserReward(level: \(3), rewardCount: \(rewards.count))"
        )
        let notify: LevelUpgradeNotify? = LevelUpgradeNotify(uid: 7, crrLevel: 12)
        #expect(
            AppRoute.levelUpgradeDialog(notify: notify).description
                == "levelUpgradeDialog(uid: \(notify?.uid ?? 0), level: \(notify?.crrLevel ?? 0))"
        )
        #expect(AppRoute.levelUpgradeDialog(notify: nil).description == "levelUpgradeDialog(uid: 0, level: 0)")
        let config = GameConfig(gameId: nil)
        let state = GameState(resumeGameData: [1])
        #expect(
            AppRoute.webGame(config: config, state: state, autoStartMatch: false).description
                == "webGame(gameId: \(config.gameId ?? "nil"), hasResumeData: \(state.resumeGameData != nil), autoStartMatch: \(false))"
        )
    }
}
