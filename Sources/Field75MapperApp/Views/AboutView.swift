import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Field75 Mapper", systemImage: "keyboard")
                .font(.largeTitle.weight(.semibold))

            Text("A small macOS utility for remapping NuPhy Field75 G keys using the recovered Field Console HID protocol.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Persistent keyboard mappings are written to the keyboard.", systemImage: "checkmark.circle")
                Label("Hardware actions use the recovered Field Console consumer-control values.", systemImage: "play.circle")
                Label("Mac Macros use F13-F20 carrier keys while this app is running.", systemImage: "bolt.circle")
                Label("Firmware flashing, bootloader entry, and arbitrary HID reports are not implemented.", systemImage: "shield")
                Label("Readback can be stale after writes, so intended G-key state is stored locally.", systemImage: "exclamationmark.triangle")
            }
            .font(.body)

            Spacer()
        }
        .padding(24)
    }
}
