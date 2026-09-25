import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// The expansion shared by `@Describable`, which generates the built-in
/// targets, and `@DescribableProperties`, which generates custom properties.
///
/// Custom properties live in a separate macro because generating them needs
/// `names: arbitrary`, and a macro declaring arbitrary names makes the
/// compiler count a hand-written `==` twice when `Equatable` cannot be
/// synthesized (for example on enums with closure payloads).
enum DescriptionPipeline {
    /// Builds the request from the type's `@Describable` attribute, which
    /// carries the options for both macros.
    static func request(
        describable attribute: AttributeSyntax,
        declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext,
        log: inout DiagnosticLog
    ) -> ExpansionRequest? {
        guard let kind = DeclarationKind(declaration) else {
            log.report(.unsupportedDeclaration, at: attribute)
            return nil
        }
        return ExpansionRequest(
            attribute: attribute,
            model: DeclarationModel(kind: kind, declaration: declaration, lexicalContext: context.lexicalContext),
            memberBlock: declaration.memberBlock,
            typeAttributes: declaration.attributes,
            typeTemplates: AttributeArguments.templates(in: declaration.attributes, log: &log),
            generating: AttributeArguments.generatedTargets(of: attribute, log: &log)?.map { (target: $0.0, argument: $0.1) },
            defaultSource: AttributeArguments.defaultSource(of: attribute, log: &log)
        )
    }

    static func generate(for request: ExpansionRequest, log: inout DiagnosticLog) -> GeneratedMembers {
        switch request.model.kind {
        case .enum:
            EnumExpansion.members(for: request, log: &log)
        case .struct, .class, .actor:
            NominalExpansion.members(for: request, log: &log)
        }
    }

    /// `extension Type: Conformances { members }`, laid out by hand because
    /// automatic formatting is disabled.
    static func extensionDecl(
        for type: some TypeSyntaxProtocol,
        conformances: [String],
        members: [String]
    ) -> [ExtensionDeclSyntax] {
        let conformanceClause = conformances.isEmpty ? "" : ": " + conformances.joined(separator: ", ")
        let body = members.joined(separator: "\n\n")
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
}

extension AttributeListSyntax {
    /// The first attribute spelled `@<name>` or `@Description.<name>`.
    func attribute(named name: String) -> AttributeSyntax? {
        lazy.compactMap { $0.as(AttributeSyntax.self) }.first { $0.isNamed(name) }
    }
}
