/// Generates the members of a struct's, class's, or actor's `@Describable`
/// extension.
enum NominalExpansion {
    static func members(for request: ExpansionRequest, log: inout DiagnosticLog) -> [String] {
        guard let descriptionSource = request.configuration.description else {
            log.report(.missingTemplate(request.model.kind), at: request.attribute)
            return []
        }
        let resolver = NominalMemberBindingResolver(
            model: request.model,
            properties: PropertyModel.properties(in: request.memberBlock)
        )
        let description = resolver.resolve(descriptionSource, log: &log)
        return [
            DescriptionGenerator.descriptionProperty(
                modifiers: DescriptionGenerator.modifiers(for: request.model),
                body: description.stringLiteral
            ),
        ]
    }
}
