import SwiftDiagnostics
import SwiftSyntax

/// Fix-it messages offered by `@Describable` diagnostics.
enum DescriptionFixItMessage: FixItMessage {
    case replaceField(original: String, replacement: String)
    case escapeBrace(String)
    case addTemplate(String)
    case removeTemplateArguments
    case addErrorConformance
    case removeDuplicateAttribute
    case removeConformance(String)
    case replaceConformance(original: String, replacement: String)

    var message: String {
        switch self {
        case let .replaceField(original, replacement): "replace '\(original)' with '\(replacement)'"
        case let .escapeBrace(brace): "use '\(brace)\(brace)' for a literal '\(brace)'"
        case let .addTemplate(template): "add template \"\(template)\""
        case .removeTemplateArguments: "remove the template arguments"
        case .addErrorConformance: "add 'Error' conformance"
        case .removeDuplicateAttribute: "remove the duplicate @Description"
        case let .removeConformance(name): "remove '\(name)' conformance"
        case let .replaceConformance(original, replacement): "replace '\(original)' with '\(replacement)'"
        }
    }

    var fixItID: MessageID {
        MessageID(domain: "Describable", id: String(describing: self))
    }
}

/// Builders for the fix-its offered by `@Describable` diagnostics. Only
/// edits whose outcome is unambiguous are offered.
enum FixIts {
    /// Replaces the UTF-8 `range` of a template's text with `replacement`.
    static func replaceTemplateText(
        _ range: Range<Int>,
        in source: TemplateSource,
        with replacement: String,
        message: DescriptionFixItMessage
    ) -> FixIt? {
        guard let token = source.contentToken else { return nil }
        let utf8 = Array(token.text.utf8)
        guard range.upperBound <= utf8.count else { return nil }
        let newText = String(decoding: utf8[..<range.lowerBound], as: UTF8.self)
            + replacement
            + String(decoding: utf8[range.upperBound...], as: UTF8.self)
        return FixIt(
            message: message,
            changes: [.replace(oldNode: Syntax(token), newNode: Syntax(token.with(\.tokenKind, .stringSegment(newText))))]
        )
    }

    /// Adds `template` as the first argument of `attribute`.
    static func addTemplate(_ template: String, to attribute: AttributeSyntax) -> FixIt {
        let templateArgument = LabeledExprSyntax(expression: StringLiteralExprSyntax(content: template))
        let existing: [LabeledExprSyntax] = if case let .argumentList(list)? = attribute.arguments { Array(list) } else { [] }
        let arguments = existing.isEmpty
            ? [templateArgument]
            : [templateArgument.with(\.trailingComma, .commaToken(trailingTrivia: .space))] + existing
        let newAttribute = attribute
            .with(\.leftParen, .leftParenToken())
            .with(\.arguments, .argumentList(LabeledExprListSyntax(arguments)))
            .with(\.rightParen, .rightParenToken())
        return FixIt(
            message: DescriptionFixItMessage.addTemplate(template),
            changes: [.replace(oldNode: Syntax(attribute), newNode: Syntax(newAttribute))]
        )
    }

    /// Turns `@Describable(...)` into `@Describable`.
    static func removeArguments(of attribute: AttributeSyntax) -> FixIt {
        let trailingTrivia = attribute.trailingTrivia
        let newAttribute = attribute
            .with(\.leftParen, nil)
            .with(\.arguments, nil)
            .with(\.rightParen, nil)
            .with(\.trailingTrivia, trailingTrivia)
        return FixIt(
            message: DescriptionFixItMessage.removeTemplateArguments,
            changes: [.replace(oldNode: Syntax(attribute), newNode: Syntax(newAttribute))]
        )
    }

    /// Removes `attribute` from the attribute list containing it.
    static func removeAttribute(_ attribute: AttributeSyntax) -> FixIt? {
        guard let list = attribute.parent?.as(AttributeListSyntax.self) else { return nil }
        let remaining = list.filter { element in
            if case let .attribute(other) = element { other.id != attribute.id } else { true }
        }
        return FixIt(
            message: DescriptionFixItMessage.removeDuplicateAttribute,
            changes: [.replace(oldNode: Syntax(list), newNode: Syntax(AttributeListSyntax(Array(remaining))))]
        )
    }

    /// Removes `inherited` from `clause`, or the whole clause if it is the
    /// only entry.
    static func removeInheritedType(
        _ inherited: InheritedTypeSyntax,
        from clause: InheritanceClauseSyntax,
        message: DescriptionFixItMessage
    ) -> FixIt {
        let remaining = clause.inheritedTypes.filter { $0.id != inherited.id }
        guard let last = remaining.last else {
            let change = clause.parent.flatMap { replacingInheritanceClause(of: $0, with: nil) }
            return FixIt(message: message, changes: change.map { [$0] } ?? [])
        }
        let newTypes = remaining.dropLast() + [last.with(\.trailingComma, nil).with(\.trailingTrivia, clause.trailingTrivia)]
        return FixIt(
            message: message,
            changes: [
                .replace(
                    oldNode: Syntax(clause.inheritedTypes),
                    newNode: Syntax(InheritedTypeListSyntax(Array(newTypes)))
                ),
            ]
        )
    }

    /// Replaces the type named by `inherited` with `replacement`.
    static func replaceInheritedType(_ inherited: InheritedTypeSyntax, with replacement: String) -> FixIt {
        let newType = TypeSyntax(IdentifierTypeSyntax(name: .identifier(replacement))).with(\.trailingTrivia, inherited.type.trailingTrivia)
        return FixIt(
            message: DescriptionFixItMessage.replaceConformance(
                original: inherited.type.trimmedDescription,
                replacement: replacement
            ),
            changes: [.replace(oldNode: Syntax(inherited.type), newNode: Syntax(newType))]
        )
    }

    /// Adds `Error` to the declaration's inheritance clause.
    static func addErrorConformance(to declaration: some DeclGroupSyntax) -> FixIt? {
        let change: FixIt.Change? = if let clause = declaration.inheritanceClause {
            .replace(oldNode: Syntax(clause), newNode: Syntax(appendingError(to: clause)))
        } else {
            replacingInheritanceClause(
                of: Syntax(declaration),
                with: InheritanceClauseSyntax(
                    colon: .colonToken(trailingTrivia: .space),
                    inheritedTypes: [InheritedTypeSyntax(type: TypeSyntax("Error"))]
                )
            )
        }
        return change.map { FixIt(message: DescriptionFixItMessage.addErrorConformance, changes: [$0]) }
    }

    private static func appendingError(to clause: InheritanceClauseSyntax) -> InheritanceClauseSyntax {
        let types = Array(clause.inheritedTypes)
        guard let last = types.last else { return clause }
        let trailingTrivia = last.trailingTrivia
        let separated = types.dropLast() + [
            last.with(\.trailingTrivia, []).with(\.trailingComma, .commaToken(trailingTrivia: .space)),
        ]
        let error = InheritedTypeSyntax(type: TypeSyntax("Error")).with(\.trailingTrivia, trailingTrivia)
        return clause.with(\.inheritedTypes, InheritedTypeListSyntax(Array(separated) + [error]))
    }

    /// Replaces the whole declaration with a copy whose inheritance clause is
    /// `clause`. Optional children cannot be inserted or removed with
    /// node-level edits on their own, so the declaration is the edited node.
    private static func replacingInheritanceClause(of declaration: Syntax, with clause: InheritanceClauseSyntax?) -> FixIt.Change? {
        if let decl = declaration.as(StructDeclSyntax.self) {
            return replacing(decl, with: settingInheritanceClause(clause, of: decl))
        }
        if let decl = declaration.as(EnumDeclSyntax.self) {
            return replacing(decl, with: settingInheritanceClause(clause, of: decl))
        }
        if let decl = declaration.as(ClassDeclSyntax.self) {
            return replacing(decl, with: settingInheritanceClause(clause, of: decl))
        }
        if let decl = declaration.as(ActorDeclSyntax.self) {
            return replacing(decl, with: settingInheritanceClause(clause, of: decl))
        }
        return nil
    }

    private static func replacing(_ old: some SyntaxProtocol, with new: some SyntaxProtocol) -> FixIt.Change {
        .replace(oldNode: Syntax(old), newNode: Syntax(new))
    }

    /// Sets the inheritance clause that follows the name or generic
    /// parameter clause, keeping the whitespace before the body in place.
    private static func settingInheritanceClause<Decl: DeclGroupSyntax & NamedDeclSyntax & WithGenericParametersSyntax>(
        _ clause: InheritanceClauseSyntax?,
        of decl: Decl
    ) -> Decl {
        let bodyTrivia = decl.inheritanceClause?.trailingTrivia
            ?? decl.genericParameterClause?.trailingTrivia
            ?? decl.name.trailingTrivia
        let header = decl
            .with(\.genericParameterClause, decl.genericParameterClause?.with(\.trailingTrivia, clause == nil ? bodyTrivia : []))
            .with(\.name, decl.genericParameterClause == nil ? decl.name.with(\.trailingTrivia, clause == nil ? bodyTrivia : []) : decl.name)
        return header.with(\.inheritanceClause, clause?.with(\.trailingTrivia, bodyTrivia))
    }
}

/// Finds the closest spelling among `candidates` for a misspelled name.
enum SpellingSuggestion {
    static func closest(to name: String, in candidates: [String]) -> String? {
        let threshold = max(1, name.count / 3)
        let scored = candidates
            .map { (candidate: $0, distance: editDistance(name, $0)) }
            .filter { $0.distance <= threshold }
        guard let best = scored.min(by: { $0.distance < $1.distance }),
              scored.filter({ $0.distance == best.distance }).count == 1 else {
            return nil
        }
        return best.candidate
    }

    /// Optimal string alignment distance: insertions, deletions,
    /// substitutions, and transpositions of adjacent characters each count
    /// as one edit, so `nmae` is one edit away from `name`.
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let source = Array(lhs)
        let target = Array(rhs)
        guard !source.isEmpty else { return target.count }
        guard !target.isEmpty else { return source.count }
        var table = (0...source.count).map { row in (0...target.count).map { column in row == 0 ? column : (column == 0 ? row : 0) } }
        for row in 1...source.count {
            for column in 1...target.count {
                let cost = source[row - 1] == target[column - 1] ? 0 : 1
                var distance = min(table[row - 1][column] + 1, table[row][column - 1] + 1, table[row - 1][column - 1] + cost)
                if row > 1, column > 1, source[row - 1] == target[column - 2], source[row - 2] == target[column - 1] {
                    distance = min(distance, table[row - 2][column - 2] + 1)
                }
                table[row][column] = distance
            }
        }
        return table[source.count][target.count]
    }
}
