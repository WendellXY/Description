/// Generates the members of a struct's, class's, or actor's `@Describable`
/// extension.
enum NominalExpansion {
    static func members(for request: ExpansionRequest, log: inout DiagnosticLog) -> GeneratedMembers {
        let model = request.model
        let templates = request.typeTemplates
        let targets = TargetSelection.targets(for: request, templates: [templates], log: &log)
        let properties = PropertyModel.properties(in: request.memberBlock)
        let resolver = NominalMemberBindingResolver(model: model, properties: properties)
        let texts = templates.templates.reduce(into: [DescriptionTarget: ResolvedTemplate]()) { texts, template in
            texts[template.target] = template.source.map { resolver.resolve($0, log: &log) }
        }
        let mainText = texts[.description] ?? request.defaultSource.memberTemplate
        let needsMainText = targets.contains { $0 == .description || !templates.configures($0) }
        if needsMainText, !templates.configures(.description), request.defaultSource.memberTemplate == nil {
            log.report(
                .missingTemplate(model.kind),
                at: request.attribute,
                fixIts: FixIts.addDescriptionAttribute(
                    skeletonTemplate(for: model, properties: properties),
                    afterDescribableIn: request.typeAttributes
                ).map { [$0] } ?? []
            )
        }
        let modifiers = DescriptionGenerator.modifiers(for: model)
        let members = targets.map { target -> String in
            let body = if target != .description, let own = texts[target] {
                own.stringLiteral
            } else if target != .description, targets.contains(.description) {
                DescriptionGenerator.forwardingBody
            } else {
                mainText?.stringLiteral ?? "\"\""
            }
            return DescriptionGenerator.property(for: target, modifiers: modifiers, body: body)
        }
        return GeneratedMembers(targets: targets, members: members)
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
