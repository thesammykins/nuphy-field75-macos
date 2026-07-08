import Foundation

public struct Field75Modifier: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let leftControl = Field75Modifier(rawValue: 0x01)
    public static let leftShift = Field75Modifier(rawValue: 0x02)
    public static let leftOption = Field75Modifier(rawValue: 0x04)
    public static let leftCommand = Field75Modifier(rawValue: 0x08)
    public static let rightControl = Field75Modifier(rawValue: 0x10)
    public static let rightShift = Field75Modifier(rawValue: 0x20)
    public static let rightOption = Field75Modifier(rawValue: 0x40)
    public static let rightCommand = Field75Modifier(rawValue: 0x80)

    public var displayName: String {
        var names: [String] = []
        if contains(.leftCommand) || contains(.rightCommand) { names.append("Cmd") }
        if contains(.leftOption) || contains(.rightOption) { names.append("Option") }
        if contains(.leftControl) || contains(.rightControl) { names.append("Control") }
        if contains(.leftShift) || contains(.rightShift) { names.append("Shift") }
        return names.joined(separator: "+")
    }
}

public struct Field75Assignment: Codable, Hashable, Sendable {
    public let bytes: [UInt8]
    public let description: String

    public init(bytes: [UInt8], description: String) {
        precondition(bytes.count == 3, "Field75 assignments are exactly 3 bytes")
        self.bytes = bytes
        self.description = description
    }

    public var rawHex: String {
        "0x" + Field75Hex.string(bytes)
    }

    public static func keyboard(usage: UInt8, modifiers: Field75Modifier = []) -> Field75Assignment {
        let keyName = KeyboardUsageCatalog.name(for: usage)
        let description = modifiers.isEmpty ? keyName : "\(modifiers.displayName)+\(keyName)"
        return Field75Assignment(bytes: [0x20, modifiers.rawValue, usage], description: description)
    }

    public static func macroSlot(_ slot: UInt8) -> Field75Assignment {
        Field75Assignment(bytes: [0xd0, 0xa2, slot], description: "Macro slot \(slot)")
    }

    public static func hardwareAction(usage: UInt16) -> Field75Assignment {
        let name = Field75HardwareActionCatalog.name(for: usage)
        return Field75Assignment(
            bytes: [0x30, UInt8(usage & 0x00ff), UInt8((usage >> 8) & 0x00ff)],
            description: name
        )
    }

    public static let empty = Field75Assignment(bytes: [0x00, 0x00, 0x00], description: "Empty")

    public static func decode(index: Int, raw: [UInt8]) -> Field75AssignmentEntry {
        let assignment = Field75Assignment(bytes: raw, description: decodeDescription(raw))
        let offset = index * 3
        return Field75AssignmentEntry(
            index: index,
            offset: UInt16(offset),
            rawHex: assignment.rawHex,
            assignmentClass: decodeClass(raw),
            description: assignment.description
        )
    }

    private static func decodeClass(_ raw: [UInt8]) -> String {
        if raw == [0x00, 0x00, 0x00] { return "empty" }
        if raw == [0xff, 0xff, 0xff] { return "unused" }
        if raw[0] == 0x20 { return "keyboard" }
        if raw[0] == 0xd0 && raw[1] == 0xa2 { return "macro_slot" }
        if raw[0] == 0x30 { return "consumer_control" }
        if raw[0] == 0xa0 || raw[0] == 0x70 { return "special_\(Field75Hex.byte(raw[0]))" }
        return "unknown"
    }

    private static func decodeDescription(_ raw: [UInt8]) -> String {
        if raw == [0x00, 0x00, 0x00] { return "Empty/unset" }
        if raw == [0xff, 0xff, 0xff] { return "Unused marker" }
        if raw[0] == 0x20 {
            let modifiers = Field75Modifier(rawValue: raw[1])
            let keyName = KeyboardUsageCatalog.name(for: raw[2])
            return modifiers.isEmpty ? keyName : "\(modifiers.displayName)+\(keyName)"
        }
        if raw[0] == 0xd0 && raw[1] == 0xa2 {
            return "Macro slot \(raw[2])"
        }
        if raw[0] == 0x30 {
            let usage = UInt16(raw[1]) | (UInt16(raw[2]) << 8)
            return Field75HardwareActionCatalog.name(for: usage)
        }
        return "Unknown assignment 0x\(Field75Hex.string(raw))"
    }
}

public struct Field75HardwareAction: Codable, Hashable, Identifiable, Sendable {
    public let usage: UInt16
    public let name: String
    public let category: String
    public let aliases: [String]
    public let supportsMacOS: Bool
    public let macOSAssignment: Field75Assignment?

    public var id: UInt16 { usage }

    public var assignment: Field75Assignment {
        Field75Assignment.hardwareAction(usage: usage)
    }

    public init(usage: UInt16, name: String, category: String, aliases: [String], supportsMacOS: Bool = true, macOSAssignment: Field75Assignment? = nil) {
        self.usage = usage
        self.name = name
        self.category = category
        self.aliases = aliases
        self.supportsMacOS = supportsMacOS
        self.macOSAssignment = macOSAssignment
    }

    public func assignment(for platform: Field75HardwarePlatform) -> Field75Assignment? {
        switch platform {
        case .macOS:
            guard supportsMacOS else {
                return nil
            }
            return macOSAssignment ?? assignment
        case .windows:
            return assignment
        }
    }
}

public enum Field75HardwarePlatform: String, CaseIterable, Codable, Identifiable, Sendable {
    case macOS
    case windows

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .macOS: "macOS"
        case .windows: "Windows"
        }
    }
}

public enum Field75HardwareActionCatalog {
    public static let all: [Field75HardwareAction] = [
        Field75HardwareAction(usage: 0x00cd, name: "Play/Pause", category: "Media", aliases: ["play", "pause", "playpause", "media-play-pause"]),
        Field75HardwareAction(usage: 0x00b7, name: "Stop", category: "Media", aliases: ["media-stop"]),
        Field75HardwareAction(usage: 0x00b6, name: "Previous Track", category: "Media", aliases: ["previous", "prev", "prev-track", "media-previous"]),
        Field75HardwareAction(usage: 0x00b5, name: "Next Track", category: "Media", aliases: ["next", "next-track", "media-next"]),
        Field75HardwareAction(usage: 0x00e9, name: "Volume Up", category: "Volume", aliases: ["vol-up", "volumeup"]),
        Field75HardwareAction(usage: 0x00ea, name: "Volume Down", category: "Volume", aliases: ["vol-down", "volumedown"]),
        Field75HardwareAction(usage: 0x00e2, name: "Mute", category: "Volume", aliases: ["volume-mute"]),
        Field75HardwareAction(usage: 0x0183, name: "Launch Media Player", category: "Launch", aliases: ["media-player", "launch-media"], supportsMacOS: false),
        Field75HardwareAction(usage: 0x018a, name: "Open Mail", category: "Launch", aliases: ["mail", "email", "launch-mail"], supportsMacOS: false),
        Field75HardwareAction(usage: 0x0192, name: "Open Calculator", category: "Launch", aliases: ["calculator", "calc", "launch-calculator"], supportsMacOS: false),
        Field75HardwareAction(usage: 0x0194, name: "Open Computer", category: "Launch", aliases: ["computer", "my-computer"], supportsMacOS: false),
        Field75HardwareAction(usage: 0x0221, name: "Browser Search", category: "Browser", aliases: ["search", "web-search"], macOSAssignment: .keyboard(usage: 0x0f, modifiers: .leftCommand)),
        Field75HardwareAction(usage: 0x0223, name: "Browser Home", category: "Browser", aliases: ["home", "browser-home"], supportsMacOS: false),
        Field75HardwareAction(usage: 0x0224, name: "Browser Back", category: "Browser", aliases: ["back", "browser-back"], macOSAssignment: .keyboard(usage: 0x2f, modifiers: .leftCommand)),
        Field75HardwareAction(usage: 0x0225, name: "Browser Forward", category: "Browser", aliases: ["forward", "browser-forward"], macOSAssignment: .keyboard(usage: 0x30, modifiers: .leftCommand)),
        Field75HardwareAction(usage: 0x0226, name: "Browser Stop", category: "Browser", aliases: ["browser-stop"], macOSAssignment: .keyboard(usage: 0x29)),
        Field75HardwareAction(usage: 0x0227, name: "Browser Refresh", category: "Browser", aliases: ["refresh", "reload", "browser-refresh"], macOSAssignment: .keyboard(usage: 0x15, modifiers: .leftCommand)),
        Field75HardwareAction(usage: 0x022a, name: "Browser Favorites", category: "Browser", aliases: ["favorites", "bookmarks", "browser-favorites"], supportsMacOS: false)
    ]

    public static let byUsage: [UInt16: Field75HardwareAction] = Dictionary(uniqueKeysWithValues: all.map { ($0.usage, $0) })

    public static func actions(for platform: Field75HardwarePlatform) -> [Field75HardwareAction] {
        switch platform {
        case .macOS:
            all.filter { $0.assignment(for: .macOS) != nil }
        case .windows:
            all
        }
    }

    public static func action(named raw: String) -> Field75HardwareAction? {
        let normalized = normalize(raw)
        return all.first { action in
            normalize(action.name) == normalized || action.aliases.contains { normalize($0) == normalized }
        }
    }

    public static func name(for usage: UInt16) -> String {
        byUsage[usage]?.name ?? "Consumer usage 0x\(String(format: "%04x", usage))"
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "/", with: "")
    }
}

public struct Field75AssignmentEntry: Codable, Hashable, Sendable {
    public let index: Int
    public let offset: UInt16
    public let rawHex: String
    public let assignmentClass: String
    public let description: String

    public var offsetHex: String {
        Field75Hex.word(offset)
    }
}

public enum Field75TargetParser {
    public static func parse(_ raw: String, defaultMacroSlot: UInt8? = nil) throws -> Field75Assignment {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var targetText = trimmed
        var hardwarePlatform = Field75HardwarePlatform.macOS
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("windows:") || lowered.hasPrefix("win:") {
            hardwarePlatform = .windows
            targetText = String(trimmed.split(separator: ":", maxSplits: 1).last ?? "")
        } else if lowered.hasPrefix("macos:") || lowered.hasPrefix("mac:") {
            hardwarePlatform = .macOS
            targetText = String(trimmed.split(separator: ":", maxSplits: 1).last ?? "")
        }
        targetText = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = targetText.lowercased().replacingOccurrences(of: " ", with: "")

        if normalized == "restore" || normalized == "default" {
            guard let defaultMacroSlot else {
                throw Field75Error.invalidArgument("Target \(raw) needs a G key so the default macro slot is known.")
            }
            return .macroSlot(defaultMacroSlot)
        }

        if normalized.hasPrefix("macro") {
            let slotText = normalized
                .replacingOccurrences(of: "macroslot", with: "")
                .replacingOccurrences(of: "macro", with: "")
            guard let slot = UInt8(slotText), (1...9).contains(slot) else {
                throw Field75Error.invalidArgument("Invalid macro slot target: \(raw)")
            }
            return .macroSlot(slot)
        }

        if let hardwareAction = Field75HardwareActionCatalog.action(named: targetText) {
            guard let assignment = hardwareAction.assignment(for: hardwarePlatform) else {
                throw Field75Error.invalidArgument("\(hardwareAction.name) is not available as a hardware-only macOS assignment. Use a Mac Macro to open apps or select Windows:\(hardwareAction.name) for the raw Field Console code.")
            }
            return assignment
        }

        let parts = targetText
            .split(separator: "+")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let keyPart = parts.last else {
            throw Field75Error.invalidArgument("Missing target key.")
        }

        var modifiers: Field75Modifier = []
        for modifier in parts.dropLast() {
            switch modifier.lowercased() {
            case "cmd", "command", "gui", "win":
                modifiers.insert(.leftCommand)
            case "opt", "option", "alt":
                modifiers.insert(.leftOption)
            case "ctrl", "control":
                modifiers.insert(.leftControl)
            case "shift":
                modifiers.insert(.leftShift)
            default:
                throw Field75Error.invalidArgument("Unknown modifier: \(modifier)")
            }
        }

        guard let usage = KeyboardUsageCatalog.usage(named: keyPart) else {
            throw Field75Error.invalidArgument("Unknown keyboard target: \(keyPart)")
        }
        return .keyboard(usage: usage.usage, modifiers: modifiers)
    }
}
