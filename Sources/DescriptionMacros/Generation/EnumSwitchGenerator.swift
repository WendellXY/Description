/// One `case` arm of a generated `switch self`.
struct EnumSwitchArm {
    let patternName: String
    let associatedValues: [AssociatedValue]
    let body: ResolvedCaseTemplate

    /// `.idle`, or `let .loading(resource, _)` when values are bound.
    var pattern: String {
        guard !body.usedIndices.isEmpty else {
            return ".\(patternName)"
        }
        let bindings = associatedValues.map { value in
            body.usedIndices.contains(value.index) ? value.bindingName : "_"
        }
        return "let .\(patternName)(\(bindings.joined(separator: ", ")))"
    }
}

/// Generates `switch self { ... }` statements over an enum's cases.
enum EnumSwitchGenerator {
    static func switchStatement(over cases: [CaseTree<EnumSwitchArm>]) -> String {
        (["switch self {"] + lines(for: cases) + ["}"]).joined(separator: "\n")
    }

    private static func lines(for cases: [CaseTree<EnumSwitchArm>]) -> [String] {
        cases.flatMap { tree -> [String] in
            switch tree {
            case let .enumCase(arm):
                ["case \(arm.pattern):", "    return \(arm.body.template.stringLiteral)"]
            case let .conditional(clauses):
                clauses.flatMap { [$0.directive] + lines(for: $0.members) } + ["#endif"]
            }
        }
    }
}
