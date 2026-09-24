import SwiftSyntax

/// A property declared lexically in the annotated type's body.
struct PropertyModel {
    let name: String
    let declaration: VariableDeclSyntax
    let isStatic: Bool
    /// `let` rather than `var`.
    let isImmutable: Bool
    /// Stored, possibly with `willSet`/`didSet` observers, as opposed to computed.
    let isStored: Bool
    /// Whether the property's type annotation spells an optional.
    let isOptional: Bool

    var isNonisolated: Bool {
        declaration.modifiers.contains { $0.name.tokenKind == .keyword(.nonisolated) }
    }

    /// Whether a synchronous, `nonisolated` member of an actor may read the
    /// property: it is `nonisolated`, or it is a stored `let` constant, which
    /// the compiler allows to be read from within the module provided its
    /// type is `Sendable`. The `Sendable` requirement is left to the compiler.
    var isReadableOutsideActorIsolation: Bool {
        isNonisolated || (isImmutable && isStored)
    }

    /// Collects the properties declared in `memberBlock`, including those
    /// inside `#if` blocks. Members from superclasses, protocols, and
    /// extensions elsewhere are deliberately not visible.
    static func properties(in memberBlock: MemberBlockSyntax) -> [PropertyModel] {
        properties(in: memberBlock.members)
    }

    private static func properties(in members: MemberBlockItemListSyntax) -> [PropertyModel] {
        members.flatMap { member -> [PropertyModel] in
            if let variable = member.decl.as(VariableDeclSyntax.self) {
                return properties(in: variable)
            }
            if let ifConfig = member.decl.as(IfConfigDeclSyntax.self) {
                return ifConfig.clauses.flatMap { clause -> [PropertyModel] in
                    guard case let .decls(decls)? = clause.elements else { return [] }
                    return properties(in: decls)
                }
            }
            return []
        }
    }

    private static func properties(in variable: VariableDeclSyntax) -> [PropertyModel] {
        let isStatic = variable.modifiers.contains {
            $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
        }
        let isImmutable = variable.bindingSpecifier.tokenKind == .keyword(.let)
        return variable.bindings.flatMap { binding in
            names(in: binding.pattern).map { name in
                PropertyModel(
                    name: name,
                    declaration: variable,
                    isStatic: isStatic,
                    isImmutable: isImmutable,
                    isStored: isStored(binding),
                    isOptional: binding.pattern.is(IdentifierPatternSyntax.self)
                        && binding.typeAnnotation?.type.isSpelledAsOptional == true
                )
            }
        }
    }

    private static func names(in pattern: PatternSyntax) -> [String] {
        if let identifier = pattern.as(IdentifierPatternSyntax.self) {
            return [identifier.identifier.trimmedIdentifierName]
        }
        if let tuple = pattern.as(TuplePatternSyntax.self) {
            return tuple.elements.flatMap { names(in: $0.pattern) }
        }
        return []
    }

    private static func isStored(_ binding: PatternBindingSyntax) -> Bool {
        switch binding.accessorBlock?.accessors {
        case nil:
            return true
        case .getter?:
            return false
        case let .accessors(accessors)?:
            return accessors.allSatisfy { accessor in
                accessor.accessorSpecifier.tokenKind == .keyword(.willSet)
                    || accessor.accessorSpecifier.tokenKind == .keyword(.didSet)
            }
        }
    }
}
