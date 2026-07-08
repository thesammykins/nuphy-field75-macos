import Field75Core
import Foundation

@MainActor
final class Field75MapperStore: ObservableObject {
    @Published var selectedSection: SidebarSection = .macroKeys
    @Published var devices: [Field75Device] = []
    @Published var selectedDeviceID: UInt64?
    @Published var mappings: [GKeyMapping]
    @Published var logs: [LogEntry] = []
    @Published var isBusy = false
    @Published var actionRunnerEnabled = false
    @Published var runnerStatus = "Stopped"
    @Published var hasPendingKeyboardWrite = false

    private let client = Field75HIDClient()
    private let actionRunner = MacActionRunner()
    private let defaults = UserDefaults.standard
    private let mappingsKey = "Field75Mapper.mappings.v3"
    private let runnerEnabledKey = "Field75Mapper.runner.enabled"

    init() {
        mappings = Self.loadMappings(defaults: defaults, key: mappingsKey)
        actionRunnerEnabled = defaults.bool(forKey: runnerEnabledKey)
        runnerStatus = actionRunnerEnabled ? "Needs permission check" : "Stopped"
        log(.info, "Field75 Mapper ready. No firmware flashing or bootloader commands are implemented.")
    }

    var selectedDevice: Field75Device? {
        if let selectedDeviceID {
            return devices.first { $0.registryID == selectedDeviceID }
        }
        return controlDevices.first ?? devices.first
    }

    var effectiveSelectedDeviceID: UInt64? {
        selectedDevice?.registryID
    }

    var controlDevices: [Field75Device] {
        devices.filter(\.isField75ControlCandidate)
    }

    var hasMacMacroMappings: Bool {
        mappings.contains { $0.mode == .macMacro && $0.macMacro.isConfigured }
    }

    func refreshDevices() {
        isBusy = true
        defer { isBusy = false }
        do {
            devices = try client.listDevices()
            if selectedDeviceID == nil || !devices.contains(where: { $0.registryID == selectedDeviceID }) {
                selectedDeviceID = controlDevices.first?.registryID ?? devices.first?.registryID
            }
            if devices.isEmpty {
                log(.warning, "No Field75 HID devices found for VID 0x05ac PID 0x024f. If the CLI sees the keyboard, grant this app Input Monitoring permission and relaunch.")
            } else {
                log(.success, "Found \(devices.count) Field75 HID interface(s).")
            }
        } catch {
            log(.error, error.localizedDescription)
        }
    }

    func persistMappings() {
        do {
            let data = try JSONEncoder().encode(mappings)
            defaults.set(data, forKey: mappingsKey)
        } catch {
            log(.error, "Could not save mappings: \(error.localizedDescription)")
        }
        if actionRunnerEnabled {
            restartRunner()
        }
    }

    func markMappingsEdited() {
        hasPendingKeyboardWrite = true
        persistMappings()
    }

    func applyMappings() {
        guard let selectedDeviceID = effectiveSelectedDeviceID else {
            log(.error, "Select the 64-byte Field75 control interface before applying.")
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            persistMappings()
            log(.info, "Reading block 0x38 template from \(Field75Hex.number(selectedDeviceID)).")
            let readback = try client.readBlock38(registryID: selectedDeviceID)
            let assignments = Dictionary(uniqueKeysWithValues: mappings.map { ($0.gKey, $0.fieldAssignment) })
            let plan = try Field75RemapPlanner.makePlan(baseBlock38Memory: readback.block38Memory, assignments: assignments)
            for change in plan.changes {
                log(.info, "\(change.gKey.rawValue) \(change.before.rawHex) \(change.before.description) -> \(change.after.rawHex) \(change.after.description)")
            }
            log(.info, "Sending \(plan.frameCount) validated capture-sequence frame(s).")
            let result = try client.applyRemapPlan(plan, registryID: selectedDeviceID)
            hasPendingKeyboardWrite = false
            log(.success, "Sent \(result.sentFrameCount) frame(s); received \(result.echoes.count) echo/status frame(s).")
            if hasMacMacroMappings && !actionRunnerEnabled {
                log(.warning, "Mac Macro mappings need the runner enabled while this app is running.")
            }
        } catch {
            log(.error, error.localizedDescription)
        }
    }

    func setActionRunnerEnabled(_ enabled: Bool) {
        actionRunnerEnabled = enabled
        defaults.set(enabled, forKey: runnerEnabledKey)
        if enabled {
            restartRunner()
        } else {
            actionRunner.stop()
            runnerStatus = "Stopped"
            log(.info, "Mac Macro runner stopped.")
        }
    }

    func requestAccessibilityPermission() {
        actionRunner.requestAccessibilityPermission()
        log(.info, "Requested Accessibility permission for the Mac Macro runner.")
    }

    func resetPrivacyPermissions() {
        actionRunner.stop()
        actionRunnerEnabled = false
        defaults.set(false, forKey: runnerEnabledKey)
        do {
            try PermissionRepairService.resetPrivacyPermissions()
            runnerStatus = "Permissions reset"
            log(.success, "Reset Input Monitoring and Accessibility grants for Field75Mapper. Re-add /Applications/Field75Mapper.app in System Settings, then relaunch.")
        } catch {
            runnerStatus = error.localizedDescription
            log(.error, error.localizedDescription)
        }
    }

    func restartRunner() {
        guard actionRunnerEnabled else {
            return
        }
        let actions = macroActionsByCarrierUsage()
        guard !actions.isEmpty else {
            actionRunner.stop()
            runnerStatus = "No configured Mac Macro mappings"
            return
        }
        do {
            try actionRunner.start(actionsByCarrierUsage: actions)
            runnerStatus = "Running"
            log(.success, "Mac Macro runner active for \(actions.count) carrier key(s).")
        } catch {
            runnerStatus = error.localizedDescription
            log(.warning, error.localizedDescription)
        }
    }

    private func macroActionsByCarrierUsage() -> [UInt8: MacMacroAction] {
        var actions: [UInt8: MacMacroAction] = [:]
        for mapping in mappings where mapping.mode == .macMacro && mapping.macMacro.isConfigured {
            actions[mapping.gKey.defaultCarrierUsage] = mapping.macMacro
        }
        return actions
    }

    private func log(_ level: LogEntry.Level, _ message: String) {
        logs.insert(LogEntry(level, message), at: 0)
        if logs.count > 250 {
            logs.removeLast(logs.count - 250)
        }
    }

    private static func loadMappings(defaults: UserDefaults, key: String) -> [GKeyMapping] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([GKeyMapping].self, from: data) else {
            return GKeyMapping.defaultMappings()
        }

        var byKey = Dictionary(uniqueKeysWithValues: decoded.map { ($0.gKey, $0) })
        return GKey.allCases.map { gKey in
            if let existing = byKey.removeValue(forKey: gKey) {
                return existing
            }
            return GKeyMapping.defaultMappings().first { $0.gKey == gKey }!
        }
    }
}
