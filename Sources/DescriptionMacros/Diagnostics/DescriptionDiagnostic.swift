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
    case actorIsolatedField(name: String)
    case missingTemplate(DeclarationKind)
    case invalidTarget
    case errorTemplateRequiresError
    case duplicateConfiguration(target: DescriptionTarget)
    case explicitConformance(typeName: String, protocolName: String)
    case explicitLocalizedError
    case existingMember(name: String, protocolName: String?)
    case inheritedConformance(typeName: String, protocolName: String)
    case descriptionMisplaced
    case descriptionWithoutDescribable
    case invalidRawExpression(String)
    case rawPositionalLiteral(String)
    case invalidDefaultSource
    case customTargetsRequireProperties(names: [String])
    case propertiesRequireDescribable
    case propertiesWithoutCustomTargets

    var severity: DiagnosticSeverity {
        switch self {
        case .descriptionWithoutDescribable, .rawPositionalLiteral, .propertiesWithoutCustomTargets: .warning
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
        case let .actorIsolatedField(name):
            "'{\(name)}' refers to actor-isolated state and cannot be used in a synchronous description"
        case let .missingTemplate(kind):
            "@Describable requires a description template when applied to \(kind.article) \(kind.rawValue)"
        case .invalidTarget:
            "description target must be .description, .error, .debug, .property(\"name\"), or a string literal naming a property"
        case .errorTemplateRequiresError:
            "'.error' is only available for types conforming to Error"
        case let .duplicateConfiguration(target):
            target == .description
                ? "description is already configured for this declaration"
                : "'\(target.spelling)' description is already configured for this declaration"
        case let .explicitConformance(typeName, protocolName):
            "'\(typeName)' already declares a conformance to '\(protocolName)'; @Describable cannot synthesize a conformance that already exists"
        case .explicitLocalizedError:
            "@Describable synthesizes 'LocalizedError' for types that conform to 'Error'; declare 'Error' instead"
        case let .existingMember(name, protocolName?):
            "'\(name)' is already implemented; @Describable cannot synthesize '\(protocolName)' for a type that implements it manually"
        case let .existingMember(name, nil):
            "'\(name)' is already implemented; @Describable cannot generate it"
        case let .inheritedConformance(typeName, protocolName):
            "'\(typeName)' already conforms to '\(protocolName)' through a superclass or an extension; remove that conformance so @Describable can synthesize it"
        case .descriptionMisplaced:
            "@Description can only be applied to enum, struct, class, or actor declarations and enum cases"
        case .descriptionWithoutDescribable:
            "@Description has no effect unless the type is annotated with @Describable"
        case let .invalidRawExpression(source):
            "'{\(source)}' is not a valid Swift expression"
        case let .customTargetsRequireProperties(names):
            "custom description \(names.count == 1 ? "property" : "properties") \(names.map { "'\($0)'" }.joined(separator: ", ")) \(names.count == 1 ? "requires" : "require") @DescribableProperties"
        case .propertiesRequireDescribable:
            "@DescribableProperties requires @Describable on the same type"
        case .propertiesWithoutCustomTargets:
            "@DescribableProperties has no effect without custom description properties such as @Description(\"name\", ...)"
        case .invalidDefaultSource:
            "default must be .caseName, .rawValue, or .member(\"name\")"
        case let .rawPositionalLiteral(digits):
            "'{\(digits)}' in a raw template is the integer literal \(digits); unlabeled associated values are named _0, _1, and so on"
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
        case .actorIsolatedField: "actorIsolatedField"
        case .missingTemplate: "missingTemplate"
        case .invalidTarget: "invalidTarget"
        case .errorTemplateRequiresError: "errorTemplateRequiresError"
        case .duplicateConfiguration: "duplicateConfiguration"
        case .explicitConformance: "explicitConformance"
        case .explicitLocalizedError: "explicitLocalizedError"
        case .existingMember: "existingMember"
        case .inheritedConformance: "inheritedConformance"
        case .descriptionMisplaced: "descriptionMisplaced"
        case .descriptionWithoutDescribable: "descriptionWithoutDescribable"
        case .invalidRawExpression: "invalidRawExpression"
        case .rawPositionalLiteral: "rawPositionalLiteral"
        case .invalidDefaultSource: "invalidDefaultSource"
        case .customTargetsRequireProperties: "customTargetsRequireProperties"
        case .propertiesRequireDescribable: "propertiesRequireDescribable"
        case .propertiesWithoutCustomTargets: "propertiesWithoutCustomTargets"
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
        case let .unsupportedExpression(content):
            "'{\(content)}' is not supported in a description template; placeholders may use member paths, '?.', '?? literal' and '{path?}', and raw templates accept any expression"
        case let .invalidDefault(text):
            "the default after '??' must be a literal such as 0, \"nil\", true or nil, not '\(text)'"
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
    case errorConformanceMustBeExplicit(typeName: String)
    case isolatedPropertyDeclaredHere(name: String)

    var message: String {
        switch self {
        case let .inheritedMembersNotVisible(typeName):
            "@Describable only sees properties declared in the body of '\(typeName)'; inherited properties cannot be used"
        case let .errorConformanceMustBeExplicit(typeName):
            "@Describable only detects 'Error' in the inheritance clause of '\(typeName)'; conformances declared in extensions are not detected"
        case let .isolatedPropertyDeclaredHere(name):
            "'\(name)' is isolated to the actor; only 'nonisolated' properties and 'let' constants can be read synchronously"
        }
    }

    var noteID: MessageID {
        switch self {
        case .inheritedMembersNotVisible: MessageID(domain: "Describable", id: "inheritedMembersNotVisible")
        case .errorConformanceMustBeExplicit: MessageID(domain: "Describable", id: "errorConformanceMustBeExplicit")
        case .isolatedPropertyDeclaredHere: MessageID(domain: "Describable", id: "isolatedPropertyDeclaredHere")
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
