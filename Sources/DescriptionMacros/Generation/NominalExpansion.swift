/// Generates the members of a struct's, class's, or actor's `@Describable`
/// extension.
enum NominalExpansion {
    static func members(for request: ExpansionRequest, log: inout DiagnosticLog) -> [String] {
        let model = request.model
        let configuration = request.configuration
        model.validateErrorTemplate(configuration.errorArgument, log: &log)
        guard let descriptionSource = configuration.description else {
            log.report(.missingTemplate(model.kind), at: request.attribute)
            return []
        }
        let resolver = NominalMemberBindingResolver(
            model: model,
            properties: PropertyModel.properties(in: request.memberBlock)
        )
        let modifiers = DescriptionGenerator.modifiers(for: model)
        let description = DescriptionGenerator.descriptionProperty(
            modifiers: modifiers,
            body: resolver.resolve(descriptionSource, log: &log).stringLiteral
        )
        guard model.conformsToError else {
            return [description]
        }
        let errorBody = configuration.errorDescription.map { resolver.resolve($0, log: &log).stringLiteral }
        return [
            description,
            ErrorDescriptionGenerator.errorDescriptionProperty(
                modifiers: modifiers,
                body: errorBody ?? ErrorDescriptionGenerator.forwardingBody
            ),
        ]
    }
}
