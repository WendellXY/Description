import Description
import Testing

@Describable(default: .rawValue)
enum StatEventCode: String {
    case google = "2"
    case apple = "3"
    @Description("custom")
    case custom = "99"
}

@Describable(default: .rawValue)
enum PayErrorCode: Int, Error {
    case timeout = 1016
}

@Suite("Default sources")
struct DefaultSourceDescriptionTests {
    @Test func rawValues() {
        #expect(StatEventCode.google.description == "2")
        #expect(StatEventCode.custom.description == "custom")
        #expect(PayErrorCode.timeout.description == "1016")
        #expect(PayErrorCode.timeout.errorDescription == "1016")
    }
}
