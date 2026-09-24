import Description
import Foundation
import Testing

@Describable("Worker(id: {id}, name: {name})")
actor Worker {
    nonisolated let id: Int
    let name: String
    var pendingJobs: Int = 0

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

@Describable("Session({label})")
public actor Session {
    nonisolated var label: String { "session" }
}

@Suite("Actor descriptions")
struct ActorDescriptionTests {
    @Test func synchronousDescriptionOfNonisolatedState() {
        #expect(Worker(id: 7, name: "indexer").description == "Worker(id: 7, name: indexer)")
        #expect(String(describing: Session()) == "Session(session)")
    }
}
