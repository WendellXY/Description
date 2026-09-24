/// A template resolved against one enum case's associated values.
struct ResolvedCaseTemplate {
    let template: ResolvedTemplate
    /// Positions of the associated values the template interpolates.
    let usedIndices: Set<Int>
}

/// Resolves template placeholders against an enum case's associated values.
struct EnumCaseBindingResolver {
    let enumCase: EnumCaseModel

    /// The template used when a case has no `@Description` template: its name.
    var defaultTemplate: ResolvedCaseTemplate {
        ResolvedCaseTemplate(template: .plain(enumCase.name), usedIndices: [])
    }

    /// Resolves `source`, reporting placeholders that name no associated value.
    func resolve(_ source: TemplateSource, log: inout DiagnosticLog) -> ResolvedCaseTemplate {
        var usedIndices = Set<Int>()
        let segments = source.template.segments.map { segment -> ResolvedTemplate.Segment in
            switch segment {
            case let .literal(text):
                return .literal(text)
            case let .placeholder(placeholder):
                guard let value = associatedValue(for: placeholder, in: source, log: &log) else {
                    return .literal("")
                }
                usedIndices.insert(value.index)
                return .interpolation(Interpolation.expression(for: value.bindingName, isOptional: value.isOptional))
            }
        }
        return ResolvedCaseTemplate(
            template: ResolvedTemplate(segments: segments, rawDelimiter: source.rawDelimiter),
            usedIndices: usedIndices
        )
    }

    private func associatedValue(
        for placeholder: Placeholder,
        in source: TemplateSource,
        log: inout DiagnosticLog
    ) -> AssociatedValue? {
        let values = enumCase.associatedValues
        switch placeholder.reference {
        case let .named(name):
            if let value = values.first(where: { $0.label == name }) {
                return value
            }
            log.report(
                .unknownField(name: name, available: values.map(\.placeholderSpelling), owner: "case '\(enumCase.name)'"),
                at: source.literal,
                position: source.position(ofUTF8Offset: placeholder.range.lowerBound),
                fixIts: FixIts.correctField(placeholder, named: name, candidates: values.compactMap(\.label), in: source)
            )
            return nil
        case let .positional(index):
            if values.indices.contains(index) {
                return values[index]
            }
            log.report(
                .positionalFieldOutOfRange(index: index, owner: "case '\(enumCase.name)'", count: values.count),
                at: source.literal,
                position: source.position(ofUTF8Offset: placeholder.range.lowerBound)
            )
            return nil
        }
    }
}
