import SwiftSyntax
import SwiftSyntaxMacros

/// `@Description` only carries metadata that `@Describable` reads from the
/// enclosing enum, so its own expansion never produces declarations. It does
/// check that it is attached somewhere it can take effect.
public enum DescriptionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var log = DiagnosticLog()
        if !declaration.is(EnumCaseDeclSyntax.self) {
            log.report(.descriptionOutsideEnumCase, at: node)
        } else if node.arguments == nil || node.argumentList.isEmpty {
            log.report(.emptyDescriptionAttribute, at: node)
        } else if !isInsideDescribableEnum(context.lexicalContext) {
            log.report(.descriptionWithoutDescribable, at: node)
        }
        log.emit(in: context)
        return []
    }

    private static func isInsideDescribableEnum(_ lexicalContext: [Syntax]) -> Bool {
        guard let enumDecl = lexicalContext.first?.as(EnumDeclSyntax.self) else {
            return false
        }
        return enumDecl.attributes.contains { element in
            if case let .attribute(attribute) = element { attribute.isNamed("Describable") } else { false }
        }
    }
}

private extension AttributeSyntax {
    var argumentList: LabeledExprListSyntax {
        if case let .argumentList(list)? = arguments { list } else { [] }
    }
}
