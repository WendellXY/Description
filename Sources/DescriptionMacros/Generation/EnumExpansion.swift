import SwiftSyntax

/// Generates the members of an enum's `@Describable` extension.
enum EnumExpansion {
    static func members(for request: ExpansionRequest, log: inout DiagnosticLog) -> [String] {
        if request.configuration.description != nil || request.configuration.errorArgument != nil {
            log.report(.templateOnEnum, at: request.attribute.arguments.map(Syntax.init) ?? Syntax(request.attribute))
        }
        let cases = EnumModel.cases(in: request.memberBlock, log: &log)
        let descriptionArms = cases.map { tree in
            tree.map { enumCase in
                let resolver = EnumCaseBindingResolver(enumCase: enumCase)
                let body = enumCase.configuration.description.map { resolver.resolve($0, log: &log) }
                return EnumSwitchArm(
                    patternName: enumCase.patternName,
                    associatedValues: enumCase.associatedValues,
                    body: body ?? resolver.defaultTemplate
                )
            }
        }
        return [
            DescriptionGenerator.descriptionProperty(
                modifiers: DescriptionGenerator.modifiers(for: request.model),
                body: EnumSwitchGenerator.switchStatement(over: descriptionArms)
            ),
        ]
    }
}
