import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DescribablePlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        DescribableMacro.self,
        DescriptionMacro.self,
    ]
}
