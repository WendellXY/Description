import SwiftSyntax

/// Decides which targets `@Describable` generates.
///
/// `generating:` replaces the defaults, which are `description` plus, for
/// explicit `Error` types, `errorDescription`. Every target that has a
/// `@Description` somewhere on the type or its cases is generated as well.
/// Untargeted `@Description`s are the main text, so they do not force
/// `description` when `generating:` leaves it out.
enum TargetSelection {
    static func targets(
        for request: ExpansionRequest,
        templates: [DescriptionTemplates],
        log: inout DiagnosticLog
    ) -> [DescriptionTarget] {
        let model = request.model
        let requested = request.generating?.map(\.target)
            ?? (model.conformsToError ? [.description, .error] : [.description])
        for (target, argument) in request.generating ?? [] where target == .error {
            model.validateErrorTemplate(at: argument, log: &log)
        }
        let explicit = templates.flatMap(\.templates).filter { $0.target != .description }
        for template in explicit where template.target == .error {
            model.validateErrorTemplate(at: template.targetArgument.map(Syntax.init) ?? Syntax(template.attribute), log: &log)
        }
        return ordered(requested + explicit.map(\.target))
    }

    /// Built-in targets first, in a fixed order, then custom properties in
    /// the order they first appear.
    private static func ordered(_ targets: [DescriptionTarget]) -> [DescriptionTarget] {
        let builtIns = DescriptionTarget.builtIns.filter(targets.contains)
        let custom = targets.filter { !DescriptionTarget.builtIns.contains($0) }
        let uniqueCustom = custom.enumerated().filter { index, target in !custom[..<index].contains(target) }.map(\.element)
        return builtIns + uniqueCustom
    }
}
