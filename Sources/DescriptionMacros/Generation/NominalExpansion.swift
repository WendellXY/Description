/// Generates the members of a struct's, class's, or actor's `@Describable`
/// extension.
enum NominalExpansion {
    static func members(for request: ExpansionRequest, log: inout DiagnosticLog) -> [String] {
        let model = request.model
        let configuration = request.configuration
        model.validateErrorTemplate(configuration.errorArgument, log: &log)
        let properties = PropertyModel.properties(in: request.memberBlock)
        guard let descriptionSource = configuration.description else {
            // An invalid template has already been diagnosed.
            guard !configuration.hasDescriptionArgument else { return [] }
            log.report(
                .missingTemplate(model.kind),
                at: request.attribute,
                fixIts: [FixIts.addTemplate(skeletonTemplate(for: model, properties: properties), to: request.attribute)]
            )
            return []
        }
        let resolver = NominalMemberBindingResolver(model: model, properties: properties)
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

    /// A memberwise template such as `User(id: {id}, name: {name})` built
    /// from the stored instance properties the description can read.
    static func skeletonTemplate(for model: DeclarationModel, properties: [PropertyModel]) -> String {
        let fields = properties
            .filter { !$0.isStatic && $0.isStored }
            .filter { model.kind != .actor || $0.isReadableOutsideActorIsolation }
            .map { "\($0.name): {\($0.name)}" }
        return "\(model.name)(\(fields.joined(separator: ", ")))"
    }
}
