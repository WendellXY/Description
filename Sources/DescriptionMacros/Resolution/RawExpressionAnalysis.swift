import SwiftParser
import SwiftSyntax

/// Checks the expressions of raw templates and finds the names they use.
enum RawExpressionAnalysis {
    /// The free identifiers `expression` refers to (`a` and `b` in
    /// `a.count + b`, but not `count`), or `nil` after reporting when it is
    /// not a valid Swift expression.
    static func referencedNames(
        in expression: RawExpression,
        of source: TemplateSource,
        log: inout DiagnosticLog
    ) -> Set<String>? {
        var parser = Parser(expression.source)
        let syntax = ExprSyntax.parse(from: &parser)
        guard !syntax.hasError else {
            log.report(
                .invalidRawExpression(expression.source),
                at: source.literal,
                position: source.position(ofUTF8Offset: expression.range.lowerBound)
            )
            return nil
        }
        let collector = ReferenceCollector(viewMode: .sourceAccurate)
        collector.walk(syntax)
        return collector.names
    }
}

private final class ReferenceCollector: SyntaxVisitor {
    private(set) var names: Set<String> = []

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let isMemberName = node.parent?.as(MemberAccessExprSyntax.self)?.declName.id == node.id
        if !isMemberName {
            names.insert(node.baseName.identifier?.name ?? node.baseName.text)
        }
        return .skipChildren
    }
}
