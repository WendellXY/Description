import SwiftDiagnostics

extension FixIts {
    /// Replaces a misspelled `{name}` placeholder with the closest available
    /// field name, when there is a single close match.
    static func correctField(
        _ placeholder: Placeholder,
        named name: String,
        candidates: [String],
        in source: TemplateSource
    ) -> [FixIt] {
        guard let suggestion = SpellingSuggestion.closest(to: name, in: candidates) else {
            return []
        }
        // Only the root is replaced, so member paths and defaults survive.
        let fixIt = replaceTemplateText(
            placeholder.rootRange,
            in: source,
            with: suggestion,
            message: .replaceField(original: "{\(name)}", replacement: "{\(suggestion)}")
        )
        return fixIt.map { [$0] } ?? []
    }
}
