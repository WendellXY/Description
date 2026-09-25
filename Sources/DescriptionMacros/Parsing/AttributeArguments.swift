import SwiftDiagnostics
import SwiftSyntax

/// Reads `@Description` attributes and the options of `@Describable`.
enum AttributeArguments {
    static let descriptionAttribute = "Description"
    static let describableAttribute = "Describable"

    /// The `@Description` attributes in `attributes`, one per target; later
    /// duplicates are reported.
    static func templates(in attributes: AttributeListSyntax, log: inout DiagnosticLog) -> DescriptionTemplates {
        let parsed = attributes.compactMap { element -> DescriptionTemplate? in
            guard case let .attribute(attribute) = element, attribute.isNamed(descriptionAttribute) else { return nil }
            return template(of: attribute, log: &log)
        }
        let unique = parsed.enumerated().filter { index, template in
            guard parsed[..<index].contains(where: { $0.target == template.target }) else { return true }
            log.report(
                .duplicateConfiguration(target: template.target),
                at: template.attribute,
                fixIts: FixIts.removeAttribute(template.attribute).map { [$0] } ?? []
            )
            return false
        }
        return DescriptionTemplates(templates: unique.map(\.element))
    }

    /// Reads `@Description(template)` or `@Description(target, template)`.
    private static func template(of attribute: AttributeSyntax, log: inout DiagnosticLog) -> DescriptionTemplate? {
        let arguments = attribute.argumentList
        let unlabeled = arguments.filter { $0.label == nil }.map(\.expression)
        let targetArgument: ExprSyntax?
        let templateArgument: ExprSyntax
        switch unlabeled.count {
        case 1:
            targetArgument = nil
            templateArgument = unlabeled[0]
        case 2:
            targetArgument = unlabeled[0]
            templateArgument = unlabeled[1]
        default:
            // Rejected by the type checker or by `@Description` itself.
            return nil
        }
        let target: DescriptionTarget
        if let targetArgument {
            guard let parsed = DescriptionTarget(targetArgument) else {
                log.report(.invalidTarget, at: targetArgument)
                return nil
            }
            target = parsed
        } else {
            target = .description
        }
        return DescriptionTemplate(
            target: target,
            source: templateSource(from: templateArgument, log: &log),
            attribute: attribute,
            targetArgument: targetArgument
        )
    }

    /// The targets listed in `@Describable(generating: [...])`, or `nil`
    /// when the argument is absent.
    static func generatedTargets(of attribute: AttributeSyntax, log: inout DiagnosticLog) -> [(DescriptionTarget, ExprSyntax)]? {
        guard let argument = attribute.argumentList.first(where: { $0.label?.text == "generating" }) else {
            return nil
        }
        let elements: [ExprSyntax] = if let array = argument.expression.as(ArrayExprSyntax.self) {
            array.elements.map(\.expression)
        } else {
            [argument.expression]
        }
        return elements.compactMap { element in
            guard let target = DescriptionTarget(element) else {
                log.report(.invalidTarget, at: element)
                return nil
            }
            return (target, element)
        }
    }

    /// Parses a template argument.
    static func templateSource(from expression: ExprSyntax, log: inout DiagnosticLog) -> TemplateSource? {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else {
            log.report(.templateNotStringLiteral, at: expression)
            return nil
        }
        guard literal.openingQuote.tokenKind != .multilineStringQuote else {
            log.report(.multilineTemplate, at: literal)
            return nil
        }
        if let interpolation = literal.segments.first(where: { $0.is(ExpressionSegmentSyntax.self) }) {
            log.report(.interpolatedTemplate, at: interpolation)
            return nil
        }
        let rawText = literal.segments.compactMap { $0.as(StringSegmentSyntax.self)?.content.text }.joined()
        let rawDelimiterLength = literal.openingPounds?.text.count ?? 0
        do {
            let template = try TemplateParser.parse(rawText, rawDelimiterLength: rawDelimiterLength)
            return TemplateSource(template: template, literal: literal)
        } catch {
            let source = TemplateSource(template: Template(segments: []), literal: literal)
            for syntaxError in error.errors {
                log.report(
                    .templateSyntax(syntaxError.kind),
                    at: literal,
                    position: source.position(ofUTF8Offset: syntaxError.range.lowerBound),
                    fixIts: escapingFixIt(for: syntaxError, in: source).map { [$0] } ?? []
                )
            }
            return nil
        }
    }
}

/// Stray braces are most likely meant literally, so offer to escape them.
private func escapingFixIt(for error: TemplateSyntaxError, in source: TemplateSource) -> FixIt? {
    let brace = switch error.kind {
    case .unterminatedPlaceholder: "{"
    case .unmatchedClosingBrace: "}"
    default: String?.none
    }
    return brace.flatMap {
        FixIts.replaceTemplateText(error.range, in: source, with: $0 + $0, message: .escapeBrace($0))
    }
}

extension AttributeSyntax {
    /// Whether the attribute is spelled `@<name>` or `@Description.<name>`.
    func isNamed(_ name: String) -> Bool {
        let spelling = attributeName.trimmedDescription
        return spelling == name || spelling == "Description.\(name)"
    }

    var argumentList: LabeledExprListSyntax {
        if case let .argumentList(list)? = arguments { list } else { [] }
    }
}
