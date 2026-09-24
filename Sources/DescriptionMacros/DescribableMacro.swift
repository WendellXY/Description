import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Describable`: synthesizes `CustomStringConvertible` for enums, structs,
/// classes, and actors.
public enum DescribableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        var log = DiagnosticLog()
        let members = generatedMembers(of: node, attachedTo: declaration, in: context, log: &log)
        log.emit(in: context)
        guard let members, !log.hasErrors else {
            return []
        }
        let conformances = ["CustomStringConvertible"]
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): \(raw: conformances.joined(separator: ", ")) {
            \(raw: members.joined(separator: "\n\n"))
            }
            """
        return extensionDecl.as(ExtensionDeclSyntax.self).map { [$0] } ?? []
    }

    private static func generatedMembers(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext,
        log: inout DiagnosticLog
    ) -> [String]? {
        guard let kind = DeclarationKind(declaration) else {
            log.report(.unsupportedDeclaration, at: node)
            return nil
        }
        let model = DeclarationModel(kind: kind, declaration: declaration, lexicalContext: context.lexicalContext)
        let configuration = AttributeArguments.configuration(of: node, log: &log)
        switch kind {
        case .enum:
            return enumMembers(model: model, memberBlock: declaration.memberBlock, attribute: node, configuration: configuration, log: &log)
        case .struct, .class, .actor:
            return nil
        }
    }

    private static func enumMembers(
        model: DeclarationModel,
        memberBlock: MemberBlockSyntax,
        attribute: AttributeSyntax,
        configuration: DescriptionConfiguration,
        log: inout DiagnosticLog
    ) -> [String] {
        if configuration.description != nil || configuration.errorArgument != nil {
            log.report(.templateOnEnum, at: attribute.arguments ?? AttributeSyntax.Arguments(attribute))
        }
        let cases = EnumModel.cases(in: memberBlock, log: &log)
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
                modifiers: memberModifiers(for: model),
                body: EnumSwitchGenerator.switchStatement(over: descriptionArms)
            ),
        ]
    }

    /// Modifiers for generated members: the type's access level, so public
    /// types get public witnesses.
    static func memberModifiers(for model: DeclarationModel) -> [String] {
        model.accessModifier.map { [$0] } ?? []
    }
}

private extension AttributeSyntax.Arguments {
    /// Fallback node when an attribute has no argument list to point at.
    init(_ attribute: AttributeSyntax) {
        self = .argumentList(LabeledExprListSyntax([]))
    }
}
