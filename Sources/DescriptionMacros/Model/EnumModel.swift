import SwiftSyntax

/// Enum cases in declaration order, preserving `#if` structure so that the
/// generated `switch` only mentions cases that exist in the active build
/// configuration.
indirect enum CaseTree<Case> {
    struct Clause {
        /// `#if CONDITION`, `#elseif CONDITION`, or `#else`.
        let directive: String
        let members: [CaseTree<Case>]
    }

    case enumCase(Case)
    case conditional([Clause])

    /// Every case in the tree, in declaration order.
    var cases: [Case] {
        switch self {
        case let .enumCase(value): [value]
        case let .conditional(clauses): clauses.flatMap { $0.members.flatMap(\.cases) }
        }
    }

    /// Whether any case in the tree satisfies `predicate`.
    func contains(where predicate: (Case) -> Bool) -> Bool {
        switch self {
        case let .enumCase(value):
            predicate(value)
        case let .conditional(clauses):
            clauses.contains { clause in clause.members.contains { $0.contains(where: predicate) } }
        }
    }

    func map<Transformed>(_ transform: (Case) -> Transformed) -> CaseTree<Transformed> {
        switch self {
        case let .enumCase(value):
            .enumCase(transform(value))
        case let .conditional(clauses):
            .conditional(clauses.map { clause in
                CaseTree<Transformed>.Clause(
                    directive: clause.directive,
                    members: clause.members.map { $0.map(transform) }
                )
            })
        }
    }
}

/// A single enum case element together with its `@Description` templates.
struct EnumCaseModel {
    let element: EnumCaseElementSyntax
    /// The case name without backticks, used as the default description.
    let name: String
    /// The case name as written, used in generated patterns.
    let patternName: String
    let associatedValues: [AssociatedValue]
    let templates: DescriptionTemplates

    init(element: EnumCaseElementSyntax, templates: DescriptionTemplates) {
        self.element = element
        self.name = element.name.trimmedIdentifierName
        self.patternName = element.name.trimmedDescription
        self.associatedValues = (element.parameterClause?.parameters ?? []).enumerated().map { index, parameter in
            let name = parameter.secondName ?? parameter.firstName
            let label = name.flatMap { $0.tokenKind == .wildcard ? nil : $0.trimmedIdentifierName }
            return AssociatedValue(index: index, label: label, isOptional: parameter.type.isSpelledAsOptional)
        }
        self.templates = templates
    }
}

enum EnumModel {
    /// Collects the enum's cases and their `@Description` templates.
    static func cases(in memberBlock: MemberBlockSyntax, log: inout DiagnosticLog) -> [CaseTree<EnumCaseModel>] {
        cases(in: memberBlock.members, log: &log)
    }

    private static func cases(in members: MemberBlockItemListSyntax, log: inout DiagnosticLog) -> [CaseTree<EnumCaseModel>] {
        members.flatMap { member -> [CaseTree<EnumCaseModel>] in
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                let templates = AttributeArguments.templates(in: caseDecl.attributes, log: &log)
                return caseDecl.elements.map { .enumCase(EnumCaseModel(element: $0, templates: templates)) }
            }
            if let ifConfig = member.decl.as(IfConfigDeclSyntax.self) {
                return [.conditional(ifConfig.clauses.map { clause(from: $0, log: &log) })]
            }
            return []
        }
    }

    private static func clause(from clause: IfConfigClauseSyntax, log: inout DiagnosticLog) -> CaseTree<EnumCaseModel>.Clause {
        let condition = clause.condition.map { " \($0.trimmedDescription)" } ?? ""
        let members: [CaseTree<EnumCaseModel>] = if case let .decls(decls)? = clause.elements {
            cases(in: decls, log: &log)
        } else {
            []
        }
        return CaseTree.Clause(directive: clause.poundKeyword.text + condition, members: members)
    }
}
