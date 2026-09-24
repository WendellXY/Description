import SwiftSyntax
import SwiftSyntaxMacros

/// `@Description` only carries metadata that `@Describable` reads from the
/// enclosing enum, so its own expansion never produces declarations.
public enum DescriptionMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}
