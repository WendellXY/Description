/// Generates the computed properties that witness protocol requirements.
enum DescriptionGenerator {
    /// Modifiers for generated members: the type's access level, so that
    /// public and package types get witnesses as visible as the conformance.
    static func modifiers(for model: DeclarationModel) -> [String] {
        model.accessModifier.map { [$0] } ?? []
    }

    /// `var description: String { ... }` with the given getter body.
    static func descriptionProperty(modifiers: [String], body: String) -> String {
        computedProperty(modifiers: modifiers, name: "description", type: "String", body: body)
    }

    static func computedProperty(modifiers: [String], name: String, type: String, body: String) -> String {
        let declaration = (modifiers + ["var \(name): \(type) {"]).joined(separator: " ")
        let indentedBody = body.split(separator: "\n", omittingEmptySubsequences: false).map { "    \($0)" }
        return ([declaration] + indentedBody + ["}"]).joined(separator: "\n")
    }
}
