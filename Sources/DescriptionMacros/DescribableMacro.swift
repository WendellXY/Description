import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// `@Describable`: enables synthesis of `description`, `errorDescription`,
/// `debugDescription`, and custom properties for enums, structs, classes, and
/// actors. The text comes from `@Description` attributes.
public enum DescribableMacro: ExtensionMacro, PeerMacro {
    /// Generated code is laid out by the macro itself. Automatic formatting
    /// would also reformat expressions copied from raw templates, e.g.
    /// turning `{ $0 }.count` into `{ $0 } .count`.
    public static var formatMode: FormatMode { .disabled }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        var log = DiagnosticLog()
        let request = expansionRequest(of: node, attachedTo: declaration, in: context, log: &log)
        let generated = request.map { generatedMembers(for: $0, log: &log) }
        if let request, let generated {
            ConformanceValidation.validate(request, targets: generated.targets, protocols: protocols, log: &log)
        }
        log.emit(in: context)
        guard let generated, !log.hasErrors else {
            return []
        }
        let conformances = generated.targets.compactMap(\.conformance)
        let conformanceClause = conformances.isEmpty ? "" : ": " + conformances.joined(separator: ", ")
        let body = generated.members.joined(separator: "\n\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "" : "    \($0)" }
            .joined(separator: "\n")
        let extensionDecl: DeclSyntax = """
            extension \(type.trimmed)\(raw: conformanceClause) {
            \(raw: body)
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
            typeAttributes: declaration.attributes,
            typeTemplates: AttributeArguments.templates(in: declaration.attributes, log: &log),
            generating: AttributeArguments.generatedTargets(of: node, log: &log)?.map { (target: $0.0, argument: $0.1) }
        )
    }

    private static func generatedMembers(for request: ExpansionRequest, log: inout DiagnosticLog) -> GeneratedMembers {
        switch request.model.kind {
        case .enum:
            EnumExpansion.members(for: request, log: &log)
        case .struct, .class, .actor:
            NominalExpansion.members(for: request, log: &log)
        }
    }
}
