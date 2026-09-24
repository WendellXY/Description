import Description
import Foundation
import Testing

@Describable
enum State {
    case idle

    @Description("Loading {resource}")
    case loading(resource: String)

    @Description("Loaded {count} items")
    case loaded(count: Int)
}

@Describable
enum Comparison {
    @Description("Expected {0}, got {1}")
    case mismatch(String, String)

    @Description(#"path\{0}"#)
    case path(String)

    @Description("Object {{ id: {id} }}")
    case object(id: Int)

    case `default`, other
}

@Describable
public enum PublicDirection {
    case north
    case south
}

@Describable
package enum PackageDirection {
    case east
}

enum Outer {
    @Describable
    enum Nested {
        case inner
    }
}

@Describable
enum Mode {
    case release
    #if DEBUG
    case debug
    #endif
}

@Describable
enum Uninhabited {}

@Suite("Enum descriptions")
struct EnumDescriptionTests {
    @Test func caseNamesAreTheDefault() {
        #expect(State.idle.description == "idle")
        #expect(String(describing: Comparison.default) == "default")
        #expect(Comparison.other.description == "other")
        #expect(PublicDirection.south.description == "south")
        #expect(PackageDirection.east.description == "east")
        #expect(Outer.Nested.inner.description == "inner")
        #expect(Mode.release.description == "release")
    }

    @Test func templatesInterpolateAssociatedValues() {
        #expect(State.loading(resource: "profile").description == "Loading profile")
        #expect(State.loaded(count: 42).description == "Loaded 42 items")
        #expect(Comparison.mismatch("a", "b").description == "Expected a, got b")
        #expect(Comparison.path("x").description == #"path\x"#)
        #expect(Comparison.object(id: 42).description == "Object { id: 42 }")
        #expect("\(State.idle)" == "idle")
    }
}
