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

/// The templates configured for a type or for a single enum case.
struct DescriptionConfiguration {
    /// The `description` template, if one was given and is valid.
    let description: TemplateSource?
    /// Whether a description argument was written, even an invalid one.
    let hasDescriptionArgument: Bool
    /// The `errorDescription` template, if one was given.
    let errorDescription: TemplateSource?
    /// The `error:` argument, kept for diagnostics.
    let errorArgument: LabeledExprSyntax?

    static let empty = DescriptionConfiguration(
        description: nil,
        hasDescriptionArgument: false,
        errorDescription: nil,
        errorArgument: nil
    )
}
