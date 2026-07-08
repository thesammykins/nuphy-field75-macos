import Field75Core
import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var store: Field75MapperStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connected HID Interfaces")
                        .font(.title2.weight(.semibold))
                    Text("Select the Field75 interface with 64-byte input and output reports.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.refreshDevices()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            List(store.devices, selection: $store.selectedDeviceID) { device in
                DeviceRow(device: device)
                    .tag(device.registryID)
            }
            .listStyle(.inset)

            if store.devices.isEmpty {
                PermissionHelpView(compact: false)
            }
        }
        .padding(24)
    }
}

private struct DeviceRow: View {
    let device: Field75Device

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.isField75ControlCandidate ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(device.isField75ControlCandidate ? .green : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                Text("\(device.registryIDHex)  \(device.vendorIDHex):\(device.productIDHex)  rev \(device.versionHex)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("in \(device.maxInputReportSize ?? 0) / out \(device.maxOutputReportSize ?? 0)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
