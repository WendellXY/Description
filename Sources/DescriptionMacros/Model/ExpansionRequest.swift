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
}

/// The members generated for one `@Describable` use, and the targets they
/// implement.
struct GeneratedMembers {
    let targets: [DescriptionTarget]
    let members: [String]
}
