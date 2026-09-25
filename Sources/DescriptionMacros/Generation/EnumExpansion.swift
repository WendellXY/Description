/// An enum case with each of its `@Description` templates resolved once
/// against its associated values.
private struct ResolvedEnumCase {
    let enumCase: EnumCaseModel
    let templates: [DescriptionTarget: ResolvedCaseTemplate]
}

/// The text one case produces for one target.
private struct CaseText {
    let template: ResolvedCaseTemplate
    /// Whether the text is the case's main text, i.e. what `description`
    /// produces.
    let isMainText: Bool
}

/// Generates the members of an enum's `@Describable` extension.
enum EnumExpansion {
    static func members(for request: ExpansionRequest, log: inout DiagnosticLog) -> GeneratedMembers {
        let model = request.model
        let caseTrees = EnumModel.cases(in: request.memberBlock, log: &log)
        let allCases = caseTrees.flatMap(\.cases)
        let targets = TargetSelection.targets(
            for: request,
            templates: [request.typeTemplates] + allCases.map(\.templates),
            log: &log
        )
        // Type-level templates apply to every case that has none of its own;
        // they can refer to properties declared in the enum's body.
        let typeResolver = NominalMemberBindingResolver(
            model: model,
            properties: PropertyModel.properties(in: request.memberBlock)
        )
        let typeTexts = request.typeTemplates.templates.reduce(into: [DescriptionTarget: ResolvedTemplate]()) { texts, template in
            texts[template.target] = template.source.map { typeResolver.resolve($0, log: &log) }
        }
        let resolvedTrees = caseTrees.map { tree in tree.map { resolve($0, log: &log) } }
        let modifiers = DescriptionGenerator.modifiers(for: model)
        let members = targets.map { target in
            DescriptionGenerator.property(
                for: target,
                modifiers: modifiers,
                body: body(for: target, cases: resolvedTrees, typeTexts: typeTexts, forwards: targets.contains(.description))
            )
        }
        return GeneratedMembers(targets: targets, members: members)
    }

    private static func resolve(_ enumCase: EnumCaseModel, log: inout DiagnosticLog) -> ResolvedEnumCase {
        let resolver = EnumCaseBindingResolver(enumCase: enumCase)
        let templates = enumCase.templates.templates.reduce(into: [DescriptionTarget: ResolvedCaseTemplate]()) { resolved, template in
            resolved[template.target] = template.source.map { resolver.resolve($0, log: &log) }
                ?? resolver.defaultTemplate
        }
        return ResolvedEnumCase(enumCase: enumCase, templates: templates)
    }

    private static func body(
        for target: DescriptionTarget,
        cases: [CaseTree<ResolvedEnumCase>],
        typeTexts: [DescriptionTarget: ResolvedTemplate],
        forwards: Bool
    ) -> String {
        let usesMainTextOnly = !cases.contains { tree in
            tree.contains { !text(for: target, of: $0, typeTexts: typeTexts).isMainText }
        }
        if target != .description, forwards, usesMainTextOnly {
            return DescriptionGenerator.forwardingBody
        }
        return EnumSwitchGenerator.switchStatement(over: cases.map { tree in
            tree.map { resolved in
                EnumSwitchArm(
                    patternName: resolved.enumCase.patternName,
                    associatedValues: resolved.enumCase.associatedValues,
                    body: text(for: target, of: resolved, typeTexts: typeTexts).template
                )
            }
        })
    }

    /// The case's own template for `target`, else the type's, else the main
    /// text: the case's untargeted template, the type's, or the case name.
    private static func text(
        for target: DescriptionTarget,
        of resolved: ResolvedEnumCase,
        typeTexts: [DescriptionTarget: ResolvedTemplate]
    ) -> CaseText {
        if target != .description {
            if let own = resolved.templates[target] {
                return CaseText(template: own, isMainText: false)
            }
            if let shared = typeTexts[target] {
                return CaseText(template: ResolvedCaseTemplate(template: shared, usedIndices: []), isMainText: false)
            }
        }
        if let own = resolved.templates[.description] {
            return CaseText(template: own, isMainText: true)
        }
        if let shared = typeTexts[.description] {
            return CaseText(template: ResolvedCaseTemplate(template: shared, usedIndices: []), isMainText: true)
        }
        return CaseText(template: EnumCaseBindingResolver(enumCase: resolved.enumCase).defaultTemplate, isMainText: true)
    }
}
