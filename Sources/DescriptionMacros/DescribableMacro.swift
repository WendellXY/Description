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
        let request = ExpansionRequest(
            attribute: node,
            model: DeclarationModel(kind: kind, declaration: declaration, lexicalContext: context.lexicalContext),
            memberBlock: declaration.memberBlock,
            configuration: AttributeArguments.configuration(of: node, log: &log)
        )
        switch kind {
        case .enum:
            return EnumExpansion.members(for: request, log: &log)
        case .struct, .class:
            return NominalExpansion.members(for: request, log: &log)
        case .actor:
            return nil
        }
    }
}
