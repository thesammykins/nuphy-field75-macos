import Foundation

enum MacMacroActionKind: String, CaseIterable, Codable, Identifiable {
    case runShortcut
    case openApplication
    case openURL

    var id: String { rawValue }

    var title: String {
        switch self {
        case .runShortcut: "Run Shortcut"
        case .openApplication: "Open App"
        case .openURL: "Open URL"
        }
    }
}

struct MacMacroAction: Codable, Hashable {
    var kind: MacMacroActionKind
    var shortcutName: String
    var applicationPath: String
    var urlString: String

    static let empty = MacMacroAction(
        kind: .runShortcut,
        shortcutName: "",
        applicationPath: "",
        urlString: ""
    )

    var isConfigured: Bool {
        switch kind {
        case .runShortcut:
            !shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openApplication:
            !applicationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .openURL:
            !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var targetDescription: String {
        switch kind {
        case .runShortcut:
            let name = shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "Shortcut name required" : "Run Shortcut \"\(name)\""
        case .openApplication:
            let path = applicationPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                return "Application required"
            }
            return "Open \(Self.applicationName(forPath: path))"
        case .openURL:
            let url = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            return url.isEmpty ? "URL required" : "Open \(url)"
        }
    }

    static func applicationName(forPath path: String) -> String {
        URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
    }
}
