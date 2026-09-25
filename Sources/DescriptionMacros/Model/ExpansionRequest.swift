import SwiftSyntax

/// Everything an expansion needs to know about one `@Describable` use.
struct ExpansionRequest {
    let attribute: AttributeSyntax
    let model: DeclarationModel
    let memberBlock: MemberBlockSyntax
    /// The type's attributes. Unlike `attribute`, which the macro system
    /// detaches, these are still part of the declaration, so fix-its can
    /// insert new attributes next to `@Describable`.
    let typeAttributes: AttributeListSyntax
    /// The `@Description` attributes on the type itself.
    let typeTemplates: DescriptionTemplates
    /// `@Describable(generating: ...)`, or `nil` when absent.
    let generating: [(target: DescriptionTarget, argument: ExprSyntax)]?
    /// `@Describable(default: ...)`.
    let defaultSource: DefaultSource
}

/// The members generated for one `@Describable` use, one per target.
struct GeneratedMembers {
    let targets: [DescriptionTarget]
    let members: [(target: DescriptionTarget, code: String)]

    func members(where isIncluded: (DescriptionTarget) -> Bool) -> [String] {
        members.filter { isIncluded($0.target) }.map(\.code)
    }
}

extension DescriptionTarget {
    /// Whether `@DescribableProperties` generates this target.
    var isCustomProperty: Bool {
        if case .property = self { true } else { false }
    }
}
