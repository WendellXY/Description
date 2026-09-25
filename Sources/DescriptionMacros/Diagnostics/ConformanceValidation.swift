import SwiftDiagnostics
import SwiftSyntax

/// Rejects types that already provide what `@Describable` would generate, so
/// user-written behavior is never silently duplicated or overridden.
enum ConformanceValidation {
    /// - Parameter protocols: The conformances the compiler asked the
    ///   extension macro to add; protocols the type already conforms to
    ///   (through a superclass or an extension) are missing from it.
    static func validate(
        _ request: ExpansionRequest,
        targets: [DescriptionTarget],
        protocols: [TypeSyntax],
        log: inout DiagnosticLog
    ) {
        let model = request.model
        let properties = PropertyModel.properties(in: request.memberBlock)
        let offered = Set(protocols.map(\.lastComponentName))
        let localizedErrorDeclared = checkExplicitLocalizedError(in: model, log: &log)
        for target in targets {
            let declared = target == .error
                ? localizedErrorDeclared
                : checkExplicitConformance(of: target, in: model, log: &log)
            let implemented = checkExistingMember(of: target, in: properties, log: &log)
            guard !declared, !implemented, let protocolName = target.protocolName, !offered.contains(protocolName) else {
                continue
            }
            log.report(.inheritedConformance(typeName: model.name, protocolName: protocolName), at: request.attribute)
        }
    }

    private static func checkExplicitConformance(
        of target: DescriptionTarget,
        in model: DeclarationModel,
        log: inout DiagnosticLog
    ) -> Bool {
        guard let protocolName = target.protocolName,
              let inherited = model.inheritedType(named: protocolName),
              let clause = model.inheritanceClause else {
            return false
        }
        log.report(
            .explicitConformance(typeName: model.name, protocolName: protocolName),
            at: inherited,
            fixIts: [FixIts.removeInheritedType(inherited, from: clause, message: .removeConformance(protocolName))]
        )
        return true
    }

    /// `LocalizedError` is synthesized from `Error`, so an explicit
    /// `LocalizedError` should be spelled `Error` instead.
    private static func checkExplicitLocalizedError(in model: DeclarationModel, log: inout DiagnosticLog) -> Bool {
        guard let protocolName = DescriptionTarget.error.protocolName,
              let inherited = model.inheritedType(named: protocolName),
              let clause = model.inheritanceClause else {
            return false
        }
        let fixIt = model.conformsToError
            ? FixIts.removeInheritedType(inherited, from: clause, message: .removeConformance(protocolName))
            : FixIts.replaceInheritedType(inherited, with: "Error")
        log.report(.explicitLocalizedError, at: inherited, fixIts: [fixIt])
        return true
    }

    private static func checkExistingMember(
        of target: DescriptionTarget,
        in properties: [PropertyModel],
        log: inout DiagnosticLog
    ) -> Bool {
        guard let property = properties.first(where: { $0.name == target.propertyName && !$0.isStatic }) else {
            return false
        }
        log.report(.existingMember(name: target.propertyName, protocolName: target.protocolName), at: property.declaration)
        return true
    }
}

extension TypeSyntax {
    /// `LocalizedError` for both `LocalizedError` and `Foundation.LocalizedError`.
    var lastComponentName: String {
        trimmedDescription.split(separator: ".").last.map(String.init) ?? trimmedDescription
    }
}
