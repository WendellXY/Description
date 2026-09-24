import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Describable`: synthesizes `CustomStringConvertible` for enums, structs,
/// classes, and actors.
public enum DescribableMacro: ExtensionMacro, PeerMacro {
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

    /// Everything but the extension is a type-level concern, so the macro
    /// only generates code through its extension role. The peer role exists
    /// so that attaching `@Describable` to something that is not a type
    /// produces a diagnostic from the macro rather than a generic compiler
    /// error about macro roles.
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if !declaration.isProtocol(DeclGroupSyntax.self) {
            context.diagnose(Diagnostic(node: node, message: DescriptionDiagnostic.unsupportedDeclaration))
        }
        return []
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
