import Description
import Foundation
import Testing

@Describable
@Description("User(id: {id}, name: {name})")
struct User {
    let id: Int
    let name: String
}

@Describable
@Description("Profile(nickname: {nickname})")
struct Profile {
    let nickname: String?
}

@Describable
@Description("Box(value: {value})")
struct Box<T> {
    let value: T
}

@Describable
@Description("Object {{ id: {id} }}")
public struct PublicObject {
    public let id: Int
}

@Describable
@Description("PackageValue({value})")
package struct PackageValue {
    let value: Int
}

public enum Geometry {}

public extension Geometry {
    @Describable
    @Description("Point({x}, {y})")
    struct Point {
        let x: Int
        let y: Int
    }
}

@Describable
@Description("Counter(count: {count}, doubled: {doubled})")
struct Counter {
    var count: Int
    var doubled: Int { count * 2 }
}

@Suite("Struct descriptions")
struct StructDescriptionTests {
    @Test func interpolatesProperties() {
        #expect(User(id: 1, name: "Ada").description == "User(id: 1, name: Ada)")
        #expect(Counter(count: 2).description == "Counter(count: 2, doubled: 4)")
        #expect(Geometry.Point(x: 1, y: 2).description == "Point(1, 2)")
        #expect(PackageValue(value: 3).description == "PackageValue(3)")
    }

    @Test func usesSwiftInterpolationForOptionalsAndGenerics() {
        #expect(Profile(nickname: "ada").description == #"Profile(nickname: Optional("ada"))"#)
        #expect(Profile(nickname: nil).description == "Profile(nickname: nil)")
        #expect(Box(value: 42).description == "Box(value: 42)")
        #expect(Box(value: [1, 2]).description == "Box(value: [1, 2])")
    }

    @Test func escapedBraces() {
        #expect(String(describing: PublicObject(id: 42)) == "Object { id: 42 }")
    }
}
