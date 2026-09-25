import SwiftParser
import SwiftSyntax

/// What a raw template expression refers to.
struct RawExpressionReferences {
    /// The free identifiers used (`a` and `b` in `a.count + b`, not `count`).
    let names: Set<String>
    /// The name, when the whole expression is a single identifier.
    let soleName: String?
    /// Whether the whole expression is a member access such as `a.b` or
    /// `a?.b`, whose type the macro cannot see.
    let isMemberAccess: Bool
}

/// Checks the expressions of raw templates and finds the names they use.
enum RawExpressionAnalysis {
    /// What `expression` refers to, or `nil` after reporting when it is not a
    /// valid Swift expression.
    static func references(
        in expression: RawExpression,
        of source: TemplateSource,
        log: inout DiagnosticLog
    ) -> RawExpressionReferences? {
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
        let soleName = syntax.as(DeclReferenceExprSyntax.self).map { $0.baseName.identifier?.name ?? $0.baseName.text }
        return RawExpressionReferences(
            names: collector.names,
            soleName: soleName,
            isMemberAccess: syntax.is(MemberAccessExprSyntax.self)
        )
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
