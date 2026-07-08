import Field75Core
import Foundation

enum GKeyMappingMode: String, CaseIterable, Codable, Identifiable {
    case hardwareAction
    case keyboard
    case macMacro
    case restoreDefault

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hardwareAction: "Hardware"
        case .keyboard: "Keyboard"
        case .macMacro: "Mac Macro"
        case .restoreDefault: "Restore"
        }
    }
}

struct GKeyMapping: Codable, Hashable, Identifiable {
    var gKey: GKey
    var mode: GKeyMappingMode
    var hardwarePlatform: Field75HardwarePlatform
    var hardwareActionUsage: UInt16
    var keyboardUsage: UInt8
    var modifiers: Field75Modifier
    var macMacro: MacMacroAction

    var id: String { gKey.rawValue }

    var fieldAssignment: Field75Assignment {
        switch mode {
        case .hardwareAction:
            if let action = Field75HardwareActionCatalog.byUsage[hardwareActionUsage],
               let assignment = action.assignment(for: hardwarePlatform) {
                assignment
            } else {
                Field75HardwareActionCatalog.actions(for: hardwarePlatform).first?.assignment(for: hardwarePlatform) ?? .keyboard(usage: gKey.defaultCarrierUsage)
            }
        case .keyboard:
            Field75Assignment.keyboard(usage: keyboardUsage, modifiers: modifiers)
        case .macMacro:
            Field75Assignment.keyboard(usage: gKey.defaultCarrierUsage)
        case .restoreDefault:
            Field75Assignment.macroSlot(gKey.defaultMacroSlot)
        }
    }

    var summary: String {
        switch mode {
        case .hardwareAction:
            "\(Field75HardwareActionCatalog.name(for: hardwareActionUsage)) (\(hardwarePlatform.title)) -> \(fieldAssignment.description)"
        case .keyboard:
            fieldAssignment.description
        case .macMacro:
            "\(macMacro.targetDescription) via \(KeyboardUsageCatalog.name(for: gKey.defaultCarrierUsage))"
        case .restoreDefault:
            "Macro slot \(gKey.defaultMacroSlot)"
        }
    }

    static func defaultMappings() -> [GKeyMapping] {
        GKey.allCases.map { gKey in
            GKeyMapping(
                gKey: gKey,
                mode: .restoreDefault,
                hardwarePlatform: .macOS,
                hardwareActionUsage: 0x00b5,
                keyboardUsage: gKey.defaultCarrierUsage,
                modifiers: [],
                macMacro: .empty
            )
        }
    }
}
