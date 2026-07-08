import AppKit
import Foundation

enum MacMacroExecutor {
    static func run(_ action: MacMacroAction) {
        switch action.kind {
        case .runShortcut:
            runShortcut(named: action.shortcutName)
        case .openApplication:
            openApplication(path: action.applicationPath)
        case .openURL:
            openURL(action.urlString)
        }
    }

    private static func runShortcut(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return
        }

        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    private static func openApplication(path rawPath: String) {
        let path = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return
        }

        Task { @MainActor in
            let url = URL(fileURLWithPath: path)
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
    }

    private static func openURL(_ rawURL: String) {
        let urlString = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: urlString) else {
            return
        }

        Task { @MainActor in
            NSWorkspace.shared.open(url)
        }
    }
}
