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
        let request = expansionRequest(of: node, attachedTo: declaration, in: context, log: &log)
        request.map { ConformanceValidation.validate($0, protocols: protocols, log: &log) }
        let members = request.flatMap { generatedMembers(for: $0, log: &log) }
        log.emit(in: context)
        guard let request, let members, !log.hasErrors else {
            return []
        }
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed): \(raw: request.model.synthesizedConformances.joined(separator: ", ")) {
            \(raw: members.joined(separator: "\n\n"))
            }
            """
        return extensionDecl.as(ExtensionDeclSyntax.self).map { [$0] } ?? []
    }

    private static func expansionRequest(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext,
        log: inout DiagnosticLog
    ) -> ExpansionRequest? {
        guard let kind = DeclarationKind(declaration) else {
            log.report(.unsupportedDeclaration, at: node)
            return nil
        }
        return ExpansionRequest(
            attribute: node,
            model: DeclarationModel(kind: kind, declaration: declaration, lexicalContext: context.lexicalContext),
            memberBlock: declaration.memberBlock,
            configuration: AttributeArguments.configuration(of: node, log: &log)
        )
    }

    private static func generatedMembers(for request: ExpansionRequest, log: inout DiagnosticLog) -> [String]? {
        switch request.model.kind {
        case .enum:
            return EnumExpansion.members(for: request, log: &log)
        case .struct, .class, .actor:
            return NominalExpansion.members(for: request, log: &log)
        }
    }
}
