import SwiftSyntax

/// Everything an expansion needs to know about one `@Describable` use.
struct ExpansionRequest {
    let attribute: AttributeSyntax
    let model: DeclarationModel
    let memberBlock: MemberBlockSyntax
    /// The templates passed to `@Describable` itself.
    let configuration: DescriptionConfiguration
}
