import SwiftSyntax

/// A `String` property `@Describable` can generate, mirroring the public
/// `DescriptionTarget` type that attribute arguments are type-checked against.
enum DescriptionTarget: Hashable {
    /// `description`, witnessing `CustomStringConvertible`. Its template is
    /// the main text other targets fall back to.
    case description
    /// `errorDescription`, witnessing `LocalizedError`.
    case error
    /// `debugDescription`, witnessing `CustomDebugStringConvertible`.
    case debug
    /// A property of the user's choosing, typically required by their own
    /// protocol, which they declare on the type themselves.
    case property(String)

    /// Built-in targets in the order their members are generated.
    static let builtIns: [DescriptionTarget] = [.description, .debug, .error]

    var propertyName: String {
        switch self {
        case .description: "description"
        case .error: "errorDescription"
        case .debug: "debugDescription"
        case let .property(name): name
        }
    }

    var propertyType: String {
        self == .error ? "String?" : "String"
    }

    /// The protocol the generated extension conforms to for this target.
    /// `LocalizedError` is named through a typealias declared in the
    /// `Description` module, so expansions compile in files that do not
    /// import Foundation.
    var conformance: String? {
        switch self {
        case .description: "CustomStringConvertible"
        case .error: "_DescribableLocalizedError"
        case .debug: "CustomDebugStringConvertible"
        case .property: nil
        }
    }

    /// The protocol's name as users write it, for diagnostics.
    var protocolName: String? {
        switch self {
        case .description: "CustomStringConvertible"
        case .error: "LocalizedError"
        case .debug: "CustomDebugStringConvertible"
        case .property: nil
        }
    }

    /// How the target is written in an attribute, for diagnostics.
    var spelling: String {
        switch self {
        case .description: ".description"
        case .error: ".error"
        case .debug: ".debug"
        case let .property(name): "\"\(name)\""
        }
    }

    /// Reads a target argument: `.description`, `.error`, `.debug`,
    /// `.property("name")` (optionally qualified with `DescriptionTarget`),
    /// or a string literal naming a property.
    init?(_ expression: ExprSyntax) {
        if let memberAccess = expression.as(MemberAccessExprSyntax.self), Self.isTargetBase(memberAccess.base) {
            switch memberAccess.declName.baseName.text {
            case "description": self = .description
            case "error": self = .error
            case "debug": self = .debug
            default: return nil
            }
            return
        }
        if let call = expression.as(FunctionCallExprSyntax.self),
           let callee = call.calledExpression.as(MemberAccessExprSyntax.self),
           Self.isTargetBase(callee.base),
           callee.declName.baseName.text == "property",
           call.arguments.count == 1,
           let name = call.arguments.first.flatMap({ Self.propertyName(from: $0.expression) }) {
            self = .property(name)
            return
        }
        guard let name = Self.propertyName(from: expression) else { return nil }
        self = .property(name)
    }

    private static func isTargetBase(_ base: ExprSyntax?) -> Bool {
        guard let base else { return true }
        let spelling = base.trimmedDescription
        return spelling == "DescriptionTarget" || spelling == "Description.DescriptionTarget"
    }

    private static func propertyName(from expression: ExprSyntax) -> String? {
        guard let literal = expression.as(StringLiteralExprSyntax.self),
              literal.segments.count == 1,
              let text = literal.segments.first?.as(StringSegmentSyntax.self)?.content.text,
              PlaceholderExpressionParser.isIdentifier(text) else {
            return nil
        }
        return text
    }
}
