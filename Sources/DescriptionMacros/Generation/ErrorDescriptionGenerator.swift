/// Generates `LocalizedError.errorDescription`.
enum ErrorDescriptionGenerator {
    /// The getter body used when no `error:` template applies: the error
    /// description is the same as `description`.
    static let forwardingBody = "description"

    /// `var errorDescription: String? { ... }` with the given getter body.
    static func errorDescriptionProperty(modifiers: [String], body: String) -> String {
        DescriptionGenerator.computedProperty(modifiers: modifiers, name: "errorDescription", type: "String?", body: body)
    }
}
