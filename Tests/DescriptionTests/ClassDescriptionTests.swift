import Description
import Testing

@Describable("Client(host: {host})")
final class Client {
    let host: String

    init(host: String) {
        self.host = host
    }
}

class Base {
    let id: Int

    init(id: Int) {
        self.id = id
    }
}

@Describable("Child(name: {name})")
class Child: Base {
    var name: String

    init(id: Int, name: String) {
        self.name = name
        super.init(id: id)
    }
}

@Describable("Node(value: {value})")
open class Node<Value> {
    public let value: Value

    public init(value: Value) {
        self.value = value
    }
}

@Suite("Class descriptions")
struct ClassDescriptionTests {
    @Test func finalClass() {
        #expect(Client(host: "example.com").description == "Client(host: example.com)")
    }

    @Test func nonFinalSubclassUsesOwnProperties() {
        #expect(Child(id: 1, name: "leaf").description == "Child(name: leaf)")
    }

    @Test func genericOpenClass() {
        #expect(Node(value: 3).description == "Node(value: 3)")
    }
}
