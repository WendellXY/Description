import SwiftDiagnostics
import SwiftSyntax

/// Rejects types that already provide what `@Describable` would synthesize,
/// so user-written behavior is never silently duplicated or overridden.
enum ConformanceValidation {
    static let customStringConvertible = "CustomStringConvertible"
    static let localizedError = "LocalizedError"

    /// - Parameter protocols: The conformances the compiler asked the
    ///   extension macro to add; protocols the type already conforms to
    ///   (through a superclass or an extension) are missing from it.
    static func validate(_ request: ExpansionRequest, protocols: [TypeSyntax], log: inout DiagnosticLog) {
        let model = request.model
        let properties = PropertyModel.properties(in: request.memberBlock)
        let missing = Set([customStringConvertible, localizedError]).subtracting(protocols.map(\.lastComponentName))

        let describedExplicitly = checkExplicitConformance(customStringConvertible, in: model, log: &log)
            || checkExistingMember("description", of: customStringConvertible, in: properties, log: &log)
        if !describedExplicitly, missing.contains(customStringConvertible) {
            log.report(.inheritedConformance(typeName: model.name, protocolName: customStringConvertible), at: request.attribute)
        }

        let localizedExplicitly = checkExplicitLocalizedError(in: model, log: &log)
        guard model.conformsToError else { return }
        let errorDescribedExplicitly = localizedExplicitly
            || checkExistingMember("errorDescription", of: localizedError, in: properties, log: &log)
        if !errorDescribedExplicitly, missing.contains(localizedError) {
            log.report(.inheritedConformance(typeName: model.name, protocolName: localizedError), at: request.attribute)
        }
    }

    private static func checkExplicitConformance(
        _ protocolName: String,
        in model: DeclarationModel,
        log: inout DiagnosticLog
    ) -> Bool {
        guard let inherited = model.inheritedType(named: protocolName), let clause = model.inheritanceClause else {
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
        guard let inherited = model.inheritedType(named: localizedError), let clause = model.inheritanceClause else {
            return false
        }
        let fixIt = model.conformsToError
            ? FixIts.removeInheritedType(inherited, from: clause, message: .removeConformance(localizedError))
            : FixIts.replaceInheritedType(inherited, with: "Error")
        log.report(.explicitLocalizedError, at: inherited, fixIts: [fixIt])
        return true
    }

    private static func checkExistingMember(
        _ name: String,
        of protocolName: String,
        in properties: [PropertyModel],
        log: inout DiagnosticLog
    ) -> Bool {
        guard let property = properties.first(where: { $0.name == name && !$0.isStatic }) else {
            return false
        }
        log.report(.existingMember(name: name, protocolName: protocolName), at: property.declaration)
        return true
    }
}

extension TypeSyntax {
    /// `LocalizedError` for both `LocalizedError` and `Foundation.LocalizedError`.
    var lastComponentName: String {
        trimmedDescription.split(separator: ".").last.map(String.init) ?? trimmedDescription
    }
}
