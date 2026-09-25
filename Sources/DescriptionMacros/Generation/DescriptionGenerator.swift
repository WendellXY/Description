/// Generates the computed properties that implement description targets.
enum DescriptionGenerator {
    /// The getter body of a target that uses the same text as `description`.
    static let forwardingBody = "description"

    /// Modifiers for generated members: the type's access level, so that
    /// public and package types get witnesses as visible as the conformance,
    /// and `nonisolated` for actors, whose members are otherwise isolated and
    /// could not satisfy the synchronous protocol requirements.
    static func modifiers(for model: DeclarationModel) -> [String] {
        let access = model.accessModifier.map { [$0] } ?? []
        return model.kind == .actor ? access + ["nonisolated"] : access
    }

    /// `var <target>: String { ... }` with the given getter body.
    static func property(for target: DescriptionTarget, modifiers: [String], body: String) -> String {
        computedProperty(modifiers: modifiers, name: target.propertyName, type: target.propertyType, body: body)
    }

    static func computedProperty(modifiers: [String], name: String, type: String, body: String) -> String {
        let declaration = (modifiers + ["var \(SwiftIdentifier.escaped(name)): \(type) {"]).joined(separator: " ")
        let indentedBody = body.split(separator: "\n", omittingEmptySubsequences: false).map { "    \($0)" }
        return ([declaration] + indentedBody + ["}"]).joined(separator: "\n")
    }
}
