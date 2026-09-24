import SwiftDiagnostics
import SwiftSyntax

/// Resolves template placeholders against the instance properties declared
/// in a struct, class, or actor body.
struct NominalMemberBindingResolver {
    let model: DeclarationModel
    let properties: [PropertyModel]

    private var owner: String {
        "\(model.kind.rawValue) '\(model.name)'"
    }

    func resolve(_ source: TemplateSource, log: inout DiagnosticLog) -> ResolvedTemplate {
        let segments = source.template.segments.map { segment -> ResolvedTemplate.Segment in
            switch segment {
            case let .literal(text):
                return .literal(text)
            case let .placeholder(placeholder):
                guard let property = property(for: placeholder, in: source, log: &log) else {
                    return .literal("")
                }
                return .interpolation(
                    Interpolation.expression(for: SwiftIdentifier.escaped(property.name), isOptional: property.isOptional)
                )
            }
        }
        return ResolvedTemplate(segments: segments, rawDelimiter: source.rawDelimiter)
    }

    private func property(
        for placeholder: Placeholder,
        in source: TemplateSource,
        log: inout DiagnosticLog
    ) -> PropertyModel? {
        let position = source.position(ofUTF8Offset: placeholder.range.lowerBound)
        switch placeholder.reference {
        case let .positional(index):
            log.report(.positionalFieldOnNominal(index: index, owner: owner), at: source.literal, position: position)
            return nil
        case let .named(name):
            let matches = properties.filter { $0.name == name }
            if let property = matches.first(where: { !$0.isStatic }) {
                return checkIsolation(of: property, at: position, in: source, log: &log)
            }
            if !matches.isEmpty {
                log.report(.staticField(name: name), at: source.literal, position: position)
                return nil
            }
            log.report(
                .unknownField(name: name, available: availableFields, owner: owner),
                at: source.literal,
                position: position,
                notes: inheritanceNotes
            )
            return nil
        }
    }

    /// Actor-isolated state cannot be read from the synchronous, nonisolated
    /// `description` the macro generates.
    private func checkIsolation(
        of property: PropertyModel,
        at position: AbsolutePosition,
        in source: TemplateSource,
        log: inout DiagnosticLog
    ) -> PropertyModel? {
        guard model.kind == .actor, !property.isReadableOutsideActorIsolation else {
            return property
        }
        log.report(
            .actorIsolatedField(name: property.name),
            at: source.literal,
            position: position,
            notes: [
                Note(
                    node: Syntax(property.declaration),
                    message: DescriptionNote.isolatedPropertyDeclaredHere(name: property.name)
                ),
            ]
        )
        return nil
    }

    /// A class's superclass members are not visible to the macro; point at
    /// the inheritance clause so the limitation is discoverable.
    private var inheritanceNotes: [Note] {
        guard model.kind == .class, let superclass = model.inheritedTypes.first else {
            return []
        }
        return [Note(node: Syntax(superclass.type), message: DescriptionNote.inheritedMembersNotVisible(typeName: model.name))]
    }

    private var availableFields: [String] {
        properties.filter { !$0.isStatic }.map { "{\($0.name)}" }
    }
}
