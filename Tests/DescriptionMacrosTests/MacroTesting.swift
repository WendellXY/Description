import DescriptionMacros
import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

/// The conformances the compiler passes to `@Describable` for a type that
/// does not conform to either protocol yet.
let defaultConformances: [TypeSyntax] = ["CustomStringConvertible", "CustomDebugStringConvertible", "LocalizedError"]

/// `assertMacroExpansion` reporting failures through swift-testing.
func assertExpansion(
    _ originalSource: String,
    expandedSource: String,
    diagnostics: [DiagnosticSpec] = [],
    conformances: [TypeSyntax] = defaultConformances,
    applyFixIts: [String]? = nil,
    fixedSource: String? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) {
    assertMacroExpansion(
        originalSource,
        expandedSource: expandedSource,
        diagnostics: diagnostics,
        macroSpecs: [
            "Describable": MacroSpec(type: DescribableMacro.self, conformances: conformances),
            "DescribableProperties": MacroSpec(type: DescribablePropertiesMacro.self),
            "Description": MacroSpec(type: DescriptionMacro.self),
        ],
        applyFixIts: applyFixIts,
        fixedSource: fixedSource,
        failureHandler: { failure in
            Issue.record(
                Comment(rawValue: failure.message),
                sourceLocation: SourceLocation(
                    fileID: failure.location.fileID,
                    filePath: failure.location.filePath,
                    line: failure.location.line,
                    column: failure.location.column
                )
            )
        },
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
    )
}
