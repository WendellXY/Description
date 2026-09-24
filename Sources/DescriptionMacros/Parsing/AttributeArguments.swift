import SwiftSyntax

/// Reads the `(_ description: String? = nil, error: String? = nil)` argument
/// list shared by `@Describable` and `@Description`.
enum AttributeArguments {
    static let errorLabel = "error"

    static func configuration(of attribute: AttributeSyntax, log: inout DiagnosticLog) -> DescriptionConfiguration {
        guard case let .argumentList(arguments)? = attribute.arguments else {
            return .empty
        }
        let descriptionArgument = arguments.first { $0.label == nil }
        let errorArgument = arguments.first { $0.label?.text == errorLabel }
        return DescriptionConfiguration(
            description: descriptionArgument.flatMap { templateSource(from: $0.expression, log: &log) },
            errorDescription: errorArgument.flatMap { templateSource(from: $0.expression, log: &log) },
            errorArgument: errorArgument.flatMap { $0.expression.is(NilLiteralExprSyntax.self) ? nil : $0 }
        )
    }

    /// Parses a template argument; `nil` literals mean "not configured".
    private static func templateSource(from expression: ExprSyntax, log: inout DiagnosticLog) -> TemplateSource? {
        if expression.is(NilLiteralExprSyntax.self) {
            return nil
        }
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
                    position: source.position(ofUTF8Offset: syntaxError.range.lowerBound)
                )
            }
            return nil
        }
    }
}

extension AttributeSyntax {
    /// Whether the attribute is spelled `@<name>` or `@Description.<name>`.
    func isNamed(_ name: String) -> Bool {
        let spelling = attributeName.trimmedDescription
        return spelling == name || spelling == "Description.\(name)"
    }
}
