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

/// A single enum case element together with its `@Description` configuration.
struct EnumCaseModel {
    let element: EnumCaseElementSyntax
    /// The case name without backticks, used as the default description.
    let name: String
    /// The case name as written, used in generated patterns.
    let patternName: String
    let associatedValues: [AssociatedValue]
    let configuration: DescriptionConfiguration

    init(element: EnumCaseElementSyntax, configuration: DescriptionConfiguration) {
        self.element = element
        self.name = element.name.trimmedIdentifierName
        self.patternName = element.name.trimmedDescription
        self.associatedValues = (element.parameterClause?.parameters ?? []).enumerated().map { index, parameter in
            let name = parameter.secondName ?? parameter.firstName
            let label = name.flatMap { $0.tokenKind == .wildcard ? nil : $0.trimmedIdentifierName }
            return AssociatedValue(index: index, label: label, isOptional: parameter.type.isSpelledAsOptional)
        }
        self.configuration = configuration
    }
}

enum EnumModel {
    /// Collects the enum's cases and their `@Description` configurations.
    static func cases(in memberBlock: MemberBlockSyntax, log: inout DiagnosticLog) -> [CaseTree<EnumCaseModel>] {
        cases(in: memberBlock.members, log: &log)
    }

    private static func cases(in members: MemberBlockItemListSyntax, log: inout DiagnosticLog) -> [CaseTree<EnumCaseModel>] {
        members.flatMap { member -> [CaseTree<EnumCaseModel>] in
            if let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) {
                let configuration = configuration(of: caseDecl, log: &log)
                return caseDecl.elements.map { .enumCase(EnumCaseModel(element: $0, configuration: configuration)) }
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

    private static func configuration(of caseDecl: EnumCaseDeclSyntax, log: inout DiagnosticLog) -> DescriptionConfiguration {
        let attributes = caseDecl.attributes.compactMap { element -> AttributeSyntax? in
            guard case let .attribute(attribute) = element, attribute.isNamed("Description") else { return nil }
            return attribute
        }
        guard let first = attributes.first else {
            return .empty
        }
        for duplicate in attributes.dropFirst() {
            log.report(.duplicateConfiguration, at: duplicate)
        }
        return AttributeArguments.configuration(of: first, log: &log)
    }
}
