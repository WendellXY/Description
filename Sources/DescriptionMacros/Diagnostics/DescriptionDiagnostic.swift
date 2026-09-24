import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Every diagnostic `@Describable` and `@Description` can emit.
enum DescriptionDiagnostic: DiagnosticMessage {
    case unsupportedDeclaration
    case templateNotStringLiteral
    case multilineTemplate
    case interpolatedTemplate
    case templateSyntax(TemplateSyntaxError.Kind)
    case unknownField(name: String, available: [String], owner: String)
    case positionalFieldOutOfRange(index: Int, owner: String, count: Int)
    case positionalFieldOnNominal(index: Int, owner: String)
    case staticField(name: String)
    case missingTemplate(DeclarationKind)
    case templateOnEnum
    case duplicateConfiguration
    case emptyDescriptionAttribute
    case descriptionOutsideEnumCase
    case descriptionWithoutDescribable

    var severity: DiagnosticSeverity {
        switch self {
        case .descriptionWithoutDescribable: .warning
        default: .error
        }
    }

    var message: String {
        switch self {
        case .unsupportedDeclaration:
            "@Describable can only be applied to enum, struct, class, or actor declarations"
        case .templateNotStringLiteral:
            "description template must be a string literal"
        case .multilineTemplate:
            "multi-line string literals are not supported as description templates"
        case .interpolatedTemplate:
            "string interpolation is not supported in description templates; use '{name}' placeholders instead"
        case let .templateSyntax(kind):
            Self.message(for: kind)
        case let .unknownField(name, available, owner):
            available.isEmpty
                ? "unknown description field '\(name)'; \(owner) has no fields that can be used in a description"
                : "unknown description field '\(name)'; available fields: \(available.joined(separator: ", "))"
        case let .positionalFieldOutOfRange(index, owner, count):
            "description field '{\(index)}' does not exist; \(owner) has \(count) associated \(count == 1 ? "value" : "values")"
        case let .positionalFieldOnNominal(index, owner):
            "positional description field '{\(index)}' is only available for enum associated values; refer to the properties of \(owner) by name"
        case let .staticField(name):
            "'{\(name)}' refers to a static property; only instance properties can be used in a description"
        case let .missingTemplate(kind):
            "@Describable requires a description template when applied to \(kind.article) \(kind.rawValue)"
        case .templateOnEnum:
            "@Describable does not accept templates when applied to an enum; annotate individual cases with @Description instead"
        case .duplicateConfiguration:
            "description is already configured for this declaration"
        case .emptyDescriptionAttribute:
            "@Description requires a description template, an 'error' template, or both"
        case .descriptionOutsideEnumCase:
            "@Description can only be applied to enum cases"
        case .descriptionWithoutDescribable:
            "@Description has no effect unless the enclosing enum is annotated with @Describable"
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "Describable", id: identifier)
    }

    private var identifier: String {
        switch self {
        case .unsupportedDeclaration: "unsupportedDeclaration"
        case .templateNotStringLiteral: "templateNotStringLiteral"
        case .multilineTemplate: "multilineTemplate"
        case .interpolatedTemplate: "interpolatedTemplate"
        case .templateSyntax: "templateSyntax"
        case .unknownField: "unknownField"
        case .positionalFieldOutOfRange: "positionalFieldOutOfRange"
        case .positionalFieldOnNominal: "positionalFieldOnNominal"
        case .staticField: "staticField"
        case .missingTemplate: "missingTemplate"
        case .templateOnEnum: "templateOnEnum"
        case .duplicateConfiguration: "duplicateConfiguration"
        case .emptyDescriptionAttribute: "emptyDescriptionAttribute"
        case .descriptionOutsideEnumCase: "descriptionOutsideEnumCase"
        case .descriptionWithoutDescribable: "descriptionWithoutDescribable"
        }
    }

    private static func message(for kind: TemplateSyntaxError.Kind) -> String {
        switch kind {
        case .unterminatedPlaceholder:
            "unterminated description placeholder; use '{{' for a literal '{'"
        case .unmatchedClosingBrace:
            "unmatched '}' in description template; use '}}' for a literal '}'"
        case .emptyPlaceholder:
            "empty description placeholder; expected a field name or index"
        case let .memberPath(path):
            "member paths such as '{\(path)}' are not supported in description templates"
        case let .formatSpecifier(content):
            "format specifiers such as '{\(content)}' are not supported in description templates"
        case let .invalidPlaceholder(content):
            "invalid description placeholder '{\(content)}'; expected a field name or index"
        }
    }
}

/// Notes attached to ``DescriptionDiagnostic``s.
enum DescriptionNote: NoteMessage {
    case inheritedMembersNotVisible(typeName: String)

    var message: String {
        switch self {
        case let .inheritedMembersNotVisible(typeName):
            "@Describable only sees properties declared in the body of '\(typeName)'; inherited properties cannot be used"
        }
    }

    var noteID: MessageID {
        switch self {
        case .inheritedMembersNotVisible: MessageID(domain: "Describable", id: "inheritedMembersNotVisible")
        }
    }
}

/// Collects diagnostics during an expansion so that every problem is
/// reported at once and code is only generated when there are no errors.
struct DiagnosticLog {
    private(set) var diagnostics: [Diagnostic] = []

    var hasErrors: Bool {
        diagnostics.contains { $0.diagMessage.severity == .error }
    }

    mutating func report(
        _ message: DescriptionDiagnostic,
        at node: some SyntaxProtocol,
        position: AbsolutePosition? = nil,
        notes: [Note] = [],
        fixIts: [FixIt] = []
    ) {
        diagnostics.append(Diagnostic(node: node, position: position, message: message, notes: notes, fixIts: fixIts))
    }

    func emit(in context: some MacroExpansionContext) {
        diagnostics.forEach(context.diagnose)
    }
}
