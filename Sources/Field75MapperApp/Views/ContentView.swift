import SwiftUI

struct ContentView: View {
    @StateObject private var store = Field75MapperStore()

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $store.selectedSection)
                .frame(width: 205)

            Divider()

            VStack(spacing: 0) {
                HStack {
                    Text(store.selectedSection.title)
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 8) {
                        Button {
                            store.refreshDevices()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .labelStyle(.iconOnly)
                        }
                        .help("Refresh devices")
                        .disabled(store.isBusy)

                        ApplyMappingsButton(title: "Apply to Keyboard", prominent: store.hasPendingKeyboardWrite)
                    }
                }
                .padding(.horizontal, 18)
                .frame(height: 52)

                Divider()

                detailView
            }
        }
        .frame(minWidth: 980, minHeight: 620)
        .environmentObject(store)
        .onAppear {
            store.refreshDevices()
            if store.actionRunnerEnabled {
                store.restartRunner()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshField75Devices)) { _ in
            store.refreshDevices()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch store.selectedSection {
        case .devices:
            DevicesView()
        case .macroKeys:
            MacroKeysView()
        case .logs:
            LogsView()
        case .about:
            AboutView()
        }
    }
}
