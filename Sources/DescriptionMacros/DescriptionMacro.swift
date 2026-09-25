import SwiftSyntax
import SwiftSyntaxMacros

/// `@Description` only carries templates that `@Describable` reads from the
/// type and its cases, so its own expansion never produces declarations. It
/// does check that it is attached somewhere it can take effect.
public enum DescriptionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var log = DiagnosticLog()
        if declaration.is(EnumCaseDeclSyntax.self) {
            if !isDescribable(context.lexicalContext.first?.as(EnumDeclSyntax.self)?.attributes) {
                log.report(.descriptionWithoutDescribable, at: node)
            }
        } else if let typeDecl = declaration.asProtocol(DeclGroupSyntax.self), DeclarationKind(typeDecl) != nil {
            if !isDescribable(typeDecl.attributes) {
                log.report(.descriptionWithoutDescribable, at: node)
            }
        } else {
            log.report(.descriptionMisplaced, at: node)
        }
        log.emit(in: context)
        return []
    }

    private static func isDescribable(_ attributes: AttributeListSyntax?) -> Bool {
        (attributes ?? []).contains { element in
            if case let .attribute(attribute) = element {
                attribute.isNamed(AttributeArguments.describableAttribute)
            } else {
                false
            }
        }
    }
}
