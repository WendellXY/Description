import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// `@DescribableProperties`: generates the custom properties configured with
/// `@Description("name", ...)`.
///
/// It runs the same expansion as `@Describable`, reading the options from the
/// type's `@Describable` attribute, but emits only custom properties. Problems
/// with templates are reported by `@Describable`, so they are not repeated.
public enum DescribablePropertiesMacro: ExtensionMacro {
    public static var formatMode: FormatMode { .disabled }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let describable = declaration.attributes.attribute(named: AttributeArguments.describableAttribute) else {
            context.diagnose(Diagnostic(node: node, message: DescriptionDiagnostic.propertiesRequireDescribable))
            return []
        }
        // Diagnostics are reported by @Describable.
        var log = DiagnosticLog()
        guard let request = DescriptionPipeline.request(describable: describable, declaration: declaration, in: context, log: &log) else {
            return []
        }
        let generated = DescriptionPipeline.generate(for: request, log: &log)
        let custom = generated.targets.filter(\.isCustomProperty)
        ConformanceValidation.validate(request, targets: custom, protocols: protocols, log: &log)
        guard !log.hasErrors else {
            return []
        }
        guard !custom.isEmpty else {
            context.diagnose(Diagnostic(node: node, message: DescriptionDiagnostic.propertiesWithoutCustomTargets))
            return []
        }
        return DescriptionPipeline.extensionDecl(
            for: type,
            conformances: [],
            members: generated.members(where: \.isCustomProperty)
        )
    }
}
