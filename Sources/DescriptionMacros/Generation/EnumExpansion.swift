import SwiftSyntax

/// An enum case with its templates resolved against its associated values.
private struct ResolvedEnumCase {
    let enumCase: EnumCaseModel
    let description: ResolvedCaseTemplate
    let errorDescription: ResolvedCaseTemplate?

    var descriptionArm: EnumSwitchArm {
        arm(body: description)
    }

    /// The `errorDescription` arm; falls back to the description template so
    /// the value is produced by a single `switch`.
    var errorDescriptionArm: EnumSwitchArm {
        arm(body: errorDescription ?? description)
    }

    private func arm(body: ResolvedCaseTemplate) -> EnumSwitchArm {
        EnumSwitchArm(patternName: enumCase.patternName, associatedValues: enumCase.associatedValues, body: body)
    }
}

/// Generates the members of an enum's `@Describable` extension.
enum EnumExpansion {
    static func members(for request: ExpansionRequest, log: inout DiagnosticLog) -> [String] {
        if request.configuration.hasDescriptionArgument || request.configuration.errorArgument != nil {
            log.report(
                .templateOnEnum,
                at: request.attribute.arguments.map(Syntax.init) ?? Syntax(request.attribute),
                fixIts: [FixIts.removeArguments(of: request.attribute)]
            )
        }
        let model = request.model
        let cases = EnumModel.cases(in: request.memberBlock, log: &log).map { tree in
            tree.map { resolve($0, in: model, log: &log) }
        }
        let modifiers = DescriptionGenerator.modifiers(for: model)
        let description = DescriptionGenerator.descriptionProperty(
            modifiers: modifiers,
            body: EnumSwitchGenerator.switchStatement(over: cases.map { $0.map(\.descriptionArm) })
        )
        guard model.conformsToError else {
            return [description]
        }
        let hasErrorTemplates = cases.contains { $0.contains { $0.errorDescription != nil } }
        let errorBody = hasErrorTemplates
            ? EnumSwitchGenerator.switchStatement(over: cases.map { $0.map(\.errorDescriptionArm) })
            : ErrorDescriptionGenerator.forwardingBody
        return [description, ErrorDescriptionGenerator.errorDescriptionProperty(modifiers: modifiers, body: errorBody)]
    }

    private static func resolve(
        _ enumCase: EnumCaseModel,
        in model: DeclarationModel,
        log: inout DiagnosticLog
    ) -> ResolvedEnumCase {
        let configuration = enumCase.configuration
        model.validateErrorTemplate(configuration.errorArgument, log: &log)
        let resolver = EnumCaseBindingResolver(enumCase: enumCase)
        return ResolvedEnumCase(
            enumCase: enumCase,
            description: configuration.description.map { resolver.resolve($0, log: &log) } ?? resolver.defaultTemplate,
            errorDescription: configuration.errorDescription.map { resolver.resolve($0, log: &log) }
        )
    }
}
