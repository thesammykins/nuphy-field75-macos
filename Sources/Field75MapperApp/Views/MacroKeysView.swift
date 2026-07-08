import Field75Core
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MacroKeysView: View {
    @EnvironmentObject private var store: Field75MapperStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            StatusPill(text: "No firmware flashing", color: .green)
            if store.selectedDevice == nil {
                PermissionHelpView(compact: true)
            }
            applyCallout
            actionRunnerControls
            mappingGrid
            Spacer(minLength: 0)
        }
        .padding(24)
        .onChange(of: store.mappings) {
            store.markMappingsEdited()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "keyboard")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("NuPhy Field75")
                    .font(.title2.weight(.semibold))
                if let selectedDevice = store.selectedDevice {
                    Text("Selected \(selectedDevice.registryIDHex), revision \(selectedDevice.versionHex)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No control interface selected")
                        .foregroundStyle(.secondary)
                }
            }
            .layoutPriority(1)
            Spacer()
        }
    }

    private var applyCallout: some View {
        HStack(spacing: 12) {
            Image(systemName: store.hasPendingKeyboardWrite ? "exclamationmark.circle.fill" : "info.circle")
                .foregroundStyle(store.hasPendingKeyboardWrite ? .orange : .secondary)
            Text(store.hasPendingKeyboardWrite ? "Pending device write. Your edits are saved in the app but are not on the keyboard yet." : "Edit rows to build a local plan, then apply it to write the keyboard.")
                .foregroundStyle(store.hasPendingKeyboardWrite ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            ApplyMappingsButton(title: "Apply to Keyboard", prominent: store.hasPendingKeyboardWrite)
        }
        .font(.callout)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var actionRunnerControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                runnerToggle
                runnerStatus
                Spacer()
                accessibilityButton
                resetPermissionsButton
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    runnerToggle
                    runnerStatus
                }
                HStack {
                    accessibilityButton
                    resetPermissionsButton
                }
            }
        }
        .font(.callout)
    }

    private var runnerToggle: some View {
        Toggle(isOn: Binding(
            get: { store.actionRunnerEnabled },
            set: { store.setActionRunnerEnabled($0) }
        )) {
            Label("Mac Macro Runner", systemImage: "bolt.circle")
        }
        .toggleStyle(.switch)
    }

    private var runnerStatus: some View {
        Text(store.runnerStatus)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private var accessibilityButton: some View {
        Button {
            store.requestAccessibilityPermission()
        } label: {
            Label("Request Accessibility", systemImage: "lock.open")
        }
    }

    private var resetPermissionsButton: some View {
        Button {
            store.resetPrivacyPermissions()
        } label: {
            Label("Reset Permissions", systemImage: "arrow.counterclockwise")
        }
        .help("Reset Input Monitoring and Accessibility grants for this bundle ID")
    }

    private var mappingGrid: some View {
        ScrollView([.vertical, .horizontal]) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text("Key").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Mode").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Target").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Modifiers").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text("Writes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                Divider()
                    .gridCellColumns(5)

                ForEach($store.mappings) { $mapping in
                    GKeyMappingRow(mapping: $mapping)
                    Divider()
                        .gridCellColumns(5)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct GKeyMappingRow: View {
    @Binding var mapping: GKeyMapping

    var body: some View {
        GridRow {
            Text(mapping.gKey.rawValue)
                .font(.headline)
                .frame(width: 38, alignment: .leading)

            Picker("Mode", selection: $mapping.mode) {
                ForEach(GKeyMappingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 118)

            targetControl
                .frame(width: 380, alignment: .leading)

            modifierControls
                .frame(width: 220, alignment: .leading)

            Text(mapping.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 260, alignment: .leading)
        }
    }

    @ViewBuilder
    private var targetControl: some View {
        switch mapping.mode {
        case .hardwareAction:
            HStack(spacing: 8) {
                Picker("Platform", selection: $mapping.hardwarePlatform) {
                    ForEach(Field75HardwarePlatform.allCases) { platform in
                        Text(platform.title).tag(platform)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
                .onChange(of: mapping.hardwarePlatform) {
                    let actions = Field75HardwareActionCatalog.actions(for: mapping.hardwarePlatform)
                    if !actions.contains(where: { $0.usage == mapping.hardwareActionUsage }),
                       let first = actions.first {
                        mapping.hardwareActionUsage = first.usage
                    }
                }

                Picker("Action", selection: $mapping.hardwareActionUsage) {
                    ForEach(Field75HardwareActionCatalog.actions(for: mapping.hardwarePlatform)) { action in
                        Text(action.name).tag(action.usage)
                    }
                }
                .labelsHidden()
            }
        case .keyboard:
            Picker("Key", selection: $mapping.keyboardUsage) {
                ForEach(KeyboardUsageCatalog.all) { usage in
                    Text(usage.name).tag(usage.usage)
                }
            }
            .labelsHidden()
        case .macMacro:
            macMacroControl
        case .restoreDefault:
            Text("Macro \(mapping.gKey.defaultMacroSlot)")
                .foregroundStyle(.secondary)
        }
    }

    private var macMacroControl: some View {
        HStack(spacing: 8) {
            Picker("Macro Action", selection: $mapping.macMacro.kind) {
                ForEach(MacMacroActionKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 130)

            switch mapping.macMacro.kind {
            case .runShortcut:
                TextField("Shortcut name", text: $mapping.macMacro.shortcutName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 210)
            case .openApplication:
                TextField("Application path", text: $mapping.macMacro.applicationPath)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 168)
                Button {
                    chooseApplication()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Choose application")
            case .openURL:
                TextField("URL", text: $mapping.macMacro.urlString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 210)
            }
        }
    }

    private var modifierControls: some View {
        HStack(spacing: 6) {
            modifierToggle("Cmd", .leftCommand)
            modifierToggle("Option", .leftOption)
            modifierToggle("Ctrl", .leftControl)
            modifierToggle("Shift", .leftShift)
        }
        .disabled(mapping.mode != .keyboard)
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        if panel.runModal() == .OK, let url = panel.url {
            mapping.macMacro.applicationPath = url.path
        }
    }

    private func modifierToggle(_ title: String, _ modifier: Field75Modifier) -> some View {
        Toggle(title, isOn: Binding(
            get: { mapping.modifiers.contains(modifier) },
            set: { enabled in
                if enabled {
                    mapping.modifiers.insert(modifier)
                } else {
                    mapping.modifiers.remove(modifier)
                }
            }
        ))
        .toggleStyle(.button)
        .controlSize(.small)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }
}
