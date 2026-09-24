import SwiftDiagnostics
import SwiftSyntax

/// The nominal declaration kinds `@Describable` supports.
enum DeclarationKind: String, Sendable {
    case `enum`
    case `struct`
    case `class`
    case `actor`

    init?(_ declaration: some DeclGroupSyntax) {
        switch declaration.kind {
        case .enumDecl: self = .enum
        case .structDecl: self = .struct
        case .classDecl: self = .class
        case .actorDecl: self = .actor
        default: return nil
        }
    }

    /// The indefinite article used before the kind in diagnostics.
    var article: String {
        self == .enum || self == .actor ? "an" : "a"
    }
}

/// Syntactic facts about the annotated declaration that every kind needs.
struct DeclarationModel {
    let kind: DeclarationKind
    let name: String
    /// The name token, for diagnostics that point at the declaration.
    let nameToken: TokenSyntax
    let inheritedTypes: [InheritedTypeSyntax]
    /// The access modifier generated members must spell out so they can
    /// witness protocol requirements, e.g. `public`; `nil` for the default.
    let accessModifier: String?

    /// Whether `Error` is listed in the declaration's own inheritance clause.
    ///
    /// Conformances declared in extensions or inherited through refining
    /// protocols are not detected; the macro works on syntax only.
    var conformsToError: Bool {
        inheritedType(named: "Error") != nil
    }

    init(kind: DeclarationKind, declaration: some DeclGroupSyntax, lexicalContext: [Syntax]) {
        self.kind = kind
        self.nameToken = declaration.asProtocol(NamedDeclSyntax.self)?.name ?? .identifier("")
        self.name = nameToken.trimmedIdentifierName
        self.inheritedTypes = Array(declaration.inheritanceClause?.inheritedTypes ?? [])
        self.accessModifier = Self.accessModifier(of: declaration, lexicalContext: lexicalContext)
    }

    /// The protocols the generated extension conforms the type to.
    ///
    /// `LocalizedError` is spelled through a typealias declared in the
    /// `Description` module, which is visible wherever the macro is, so the
    /// expansion compiles even in files that do not import Foundation.
    var synthesizedConformances: [String] {
        conformsToError ? ["CustomStringConvertible", "_DescribableLocalizedError"] : ["CustomStringConvertible"]
    }

    /// Reports an `error:` template on a type that is not an explicit `Error`.
    func validateErrorTemplate(_ argument: LabeledExprSyntax?, log: inout DiagnosticLog) {
        guard let argument, !conformsToError else { return }
        log.report(
            .errorTemplateRequiresError,
            at: argument,
            notes: [Note(node: Syntax(nameToken), message: DescriptionNote.errorConformanceMustBeExplicit(typeName: name))]
        )
    }

    /// The entry of the inheritance clause naming `name` (optionally
    /// qualified with its module, e.g. `Swift.Error`).
    func inheritedType(named name: String) -> InheritedTypeSyntax? {
        inheritedTypes.first { inherited in
            inherited.type.trimmedDescription.split(separator: ".").last.map(String.init) == name
        }
    }

    private static func accessModifier(of declaration: some DeclGroupSyntax, lexicalContext: [Syntax]) -> String? {
        if let explicit = accessModifier(in: declaration.modifiers) {
            return explicit
        }
        // Members of `public extension Outer { struct Inner {} }` are public.
        guard let parentExtension = lexicalContext.first?.as(ExtensionDeclSyntax.self) else {
            return nil
        }
        return accessModifier(in: parentExtension.modifiers)
    }

    private static func accessModifier(in modifiers: DeclModifierListSyntax) -> String? {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open): return "public"
            case .keyword(.package): return "package"
            default: continue
            }
        }
        return nil
    }
}

extension TokenSyntax {
    /// The identifier's name without surrounding backticks.
    var trimmedIdentifierName: String {
        identifier?.name ?? trimmedDescription
    }
}
