import SwiftSyntax

/// Where the main text comes from when a declaration has no untargeted
/// `@Description`, mirroring the public `DescriptionSource` type.
enum DefaultSource: Equatable {
    /// The enum case's name; not available for structs, classes, and actors.
    case caseName
    /// A member of `self`, interpolated as is; `.rawValue` is `rawValue`.
    case member(String)

    /// Reads `.caseName`, `.rawValue`, or `.member("name")`, optionally
    /// qualified with `DescriptionSource`.
    init?(_ expression: ExprSyntax) {
        if let memberAccess = expression.as(MemberAccessExprSyntax.self), Self.isSourceBase(memberAccess.base) {
            switch memberAccess.declName.baseName.text {
            case "caseName": self = .caseName
            case "rawValue": self = .member("rawValue")
            default: return nil
            }
            return
        }
        guard let call = expression.as(FunctionCallExprSyntax.self),
              let callee = call.calledExpression.as(MemberAccessExprSyntax.self),
              Self.isSourceBase(callee.base),
              callee.declName.baseName.text == "member",
              call.arguments.count == 1,
              let literal = call.arguments.first?.expression.as(StringLiteralExprSyntax.self),
              literal.segments.count == 1,
              let name = literal.segments.first?.as(StringSegmentSyntax.self)?.content.text,
              PlaceholderExpressionParser.isIdentifier(name) else {
            return nil
        }
        self = .member(name)
    }

    /// The main text as a template: `"\(rawValue)"` for `.member("rawValue")`.
    var memberTemplate: ResolvedTemplate? {
        guard case let .member(name) = self else { return nil }
        return ResolvedTemplate(segments: [.interpolation(SwiftIdentifier.escaped(name))], rawDelimiter: "")
    }

    private static func isSourceBase(_ base: ExprSyntax?) -> Bool {
        guard let base else { return true }
        let spelling = base.trimmedDescription
        return spelling == "DescriptionSource" || spelling == "Description.DescriptionSource"
    }
}
