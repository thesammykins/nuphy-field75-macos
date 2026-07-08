import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case devices
    case macroKeys
    case logs
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: "Devices"
        case .macroKeys: "Macro Keys"
        case .logs: "Logs"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .devices: "keyboard"
        case .macroKeys: "square.grid.3x3"
        case .logs: "doc.text"
        case .about: "info.circle"
        }
    }
}
