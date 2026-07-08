import SwiftUI

struct ApplyMappingsButton: View {
    @EnvironmentObject private var store: Field75MapperStore
    @State private var showingApplyConfirmation = false
    let title: String
    let prominent: Bool

    var body: some View {
        if prominent {
            button
                .buttonStyle(.borderedProminent)
        } else {
            button
                .buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button {
            showingApplyConfirmation = true
        } label: {
            Label(title, systemImage: store.hasPendingKeyboardWrite ? "checkmark.circle.fill" : "checkmark.circle")
        }
        .disabled(store.isBusy || store.effectiveSelectedDeviceID == nil)
        .help("Write the current G-key plan to the keyboard")
        .alert("Apply G-key mappings?", isPresented: $showingApplyConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Apply to Keyboard", role: .destructive) {
                store.applyMappings()
            }
        } message: {
            Text("This writes the current local plan to the Field75 using the proven Field Console assignment sequence. It does not flash firmware or enter the bootloader.")
        }
    }
}
