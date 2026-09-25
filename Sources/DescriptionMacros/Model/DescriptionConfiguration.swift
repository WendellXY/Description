import SwiftSyntax

/// A parsed template together with the string literal it came from, so that
/// diagnostics can point inside the literal and generated code can reuse the
/// literal's raw-string delimiter.
struct TemplateSource {
    let template: Template
    let literal: StringLiteralExprSyntax

    /// The `#` delimiter of the literal (empty for ordinary literals).
    var rawDelimiter: String {
        literal.openingPounds?.text ?? ""
    }

    /// The token holding the literal's text; `nil` for `""`.
    var contentToken: TokenSyntax? {
        literal.segments.first?.as(StringSegmentSyntax.self)?.content
    }

    /// The source position of a UTF-8 offset within the template text.
    func position(ofUTF8Offset offset: Int) -> AbsolutePosition {
        guard let contentToken else { return literal.positionAfterSkippingLeadingTrivia }
        return contentToken.positionAfterSkippingLeadingTrivia.advanced(by: offset)
    }
}

/// One `@Description` attribute: the target it configures and its template.
struct DescriptionTemplate {
    let target: DescriptionTarget
    /// `nil` when the template was written but is invalid; it has already
    /// been diagnosed, and the target still counts as configured.
    let source: TemplateSource?
    let attribute: AttributeSyntax
    /// The target argument, when one was written, for diagnostics.
    let targetArgument: ExprSyntax?
}

/// The `@Description` attributes attached to one declaration (a type or an
/// enum case), at most one per target.
struct DescriptionTemplates {
    let templates: [DescriptionTemplate]

    static let empty = DescriptionTemplates(templates: [])

    subscript(target: DescriptionTarget) -> DescriptionTemplate? {
        templates.first { $0.target == target }
    }

    /// Whether a template, valid or not, was written for `target`.
    func configures(_ target: DescriptionTarget) -> Bool {
        self[target] != nil
    }
}
