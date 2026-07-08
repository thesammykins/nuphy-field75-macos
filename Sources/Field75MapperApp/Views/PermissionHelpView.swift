import SwiftUI

struct PermissionHelpView: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Keyboard access may need Input Monitoring permission.", systemImage: "lock.shield")
                .font(compact ? .callout.weight(.semibold) : .headline)
            Text("If `field75ctl list` sees the keyboard but this app does not, add /Applications/Field75Mapper.app in System Settings > Privacy & Security > Input Monitoring, then quit and reopen the app. Use a stable signing identity for rebuilds so macOS keeps the grant.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                SystemSettingsOpener.openPrivacySettings()
            } label: {
                Label("Open System Settings", systemImage: "gear")
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
