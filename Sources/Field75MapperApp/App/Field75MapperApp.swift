import AppKit
import SwiftUI

@main
struct Field75MapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Field75 Mapper") {
            ContentView()
                .frame(minWidth: 980, minHeight: 620)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Refresh Devices") {
                    NotificationCenter.default.post(name: .refreshField75Devices, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    static let refreshField75Devices = Notification.Name("Field75Mapper.RefreshDevices")
}
