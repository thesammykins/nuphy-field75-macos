import Foundation

public struct KeyboardUsage: Codable, Hashable, Identifiable, Sendable {
    public let usage: UInt8
    public let name: String
    public let category: String

    public var id: UInt8 { usage }

    public init(usage: UInt8, name: String, category: String) {
        self.usage = usage
        self.name = name
        self.category = category
    }
}

public enum KeyboardUsageCatalog {
    public static let all: [KeyboardUsage] = [
        KeyboardUsage(usage: 0x04, name: "A", category: "Letters"),
        KeyboardUsage(usage: 0x05, name: "B", category: "Letters"),
        KeyboardUsage(usage: 0x06, name: "C", category: "Letters"),
        KeyboardUsage(usage: 0x07, name: "D", category: "Letters"),
        KeyboardUsage(usage: 0x08, name: "E", category: "Letters"),
        KeyboardUsage(usage: 0x09, name: "F", category: "Letters"),
        KeyboardUsage(usage: 0x0a, name: "G", category: "Letters"),
        KeyboardUsage(usage: 0x0b, name: "H", category: "Letters"),
        KeyboardUsage(usage: 0x0c, name: "I", category: "Letters"),
        KeyboardUsage(usage: 0x0d, name: "J", category: "Letters"),
        KeyboardUsage(usage: 0x0e, name: "K", category: "Letters"),
        KeyboardUsage(usage: 0x0f, name: "L", category: "Letters"),
        KeyboardUsage(usage: 0x10, name: "M", category: "Letters"),
        KeyboardUsage(usage: 0x11, name: "N", category: "Letters"),
        KeyboardUsage(usage: 0x12, name: "O", category: "Letters"),
        KeyboardUsage(usage: 0x13, name: "P", category: "Letters"),
        KeyboardUsage(usage: 0x14, name: "Q", category: "Letters"),
        KeyboardUsage(usage: 0x15, name: "R", category: "Letters"),
        KeyboardUsage(usage: 0x16, name: "S", category: "Letters"),
        KeyboardUsage(usage: 0x17, name: "T", category: "Letters"),
        KeyboardUsage(usage: 0x18, name: "U", category: "Letters"),
        KeyboardUsage(usage: 0x19, name: "V", category: "Letters"),
        KeyboardUsage(usage: 0x1a, name: "W", category: "Letters"),
        KeyboardUsage(usage: 0x1b, name: "X", category: "Letters"),
        KeyboardUsage(usage: 0x1c, name: "Y", category: "Letters"),
        KeyboardUsage(usage: 0x1d, name: "Z", category: "Letters"),
        KeyboardUsage(usage: 0x1e, name: "1", category: "Numbers"),
        KeyboardUsage(usage: 0x1f, name: "2", category: "Numbers"),
        KeyboardUsage(usage: 0x20, name: "3", category: "Numbers"),
        KeyboardUsage(usage: 0x21, name: "4", category: "Numbers"),
        KeyboardUsage(usage: 0x22, name: "5", category: "Numbers"),
        KeyboardUsage(usage: 0x23, name: "6", category: "Numbers"),
        KeyboardUsage(usage: 0x24, name: "7", category: "Numbers"),
        KeyboardUsage(usage: 0x25, name: "8", category: "Numbers"),
        KeyboardUsage(usage: 0x26, name: "9", category: "Numbers"),
        KeyboardUsage(usage: 0x27, name: "0", category: "Numbers"),
        KeyboardUsage(usage: 0x28, name: "Enter", category: "Editing"),
        KeyboardUsage(usage: 0x29, name: "Escape", category: "Editing"),
        KeyboardUsage(usage: 0x2a, name: "Backspace", category: "Editing"),
        KeyboardUsage(usage: 0x2b, name: "Tab", category: "Editing"),
        KeyboardUsage(usage: 0x2c, name: "Space", category: "Editing"),
        KeyboardUsage(usage: 0x2d, name: "-", category: "Symbols"),
        KeyboardUsage(usage: 0x2e, name: "=", category: "Symbols"),
        KeyboardUsage(usage: 0x2f, name: "[", category: "Symbols"),
        KeyboardUsage(usage: 0x30, name: "]", category: "Symbols"),
        KeyboardUsage(usage: 0x31, name: "\\", category: "Symbols"),
        KeyboardUsage(usage: 0x33, name: ";", category: "Symbols"),
        KeyboardUsage(usage: 0x34, name: "'", category: "Symbols"),
        KeyboardUsage(usage: 0x35, name: "`", category: "Symbols"),
        KeyboardUsage(usage: 0x36, name: ",", category: "Symbols"),
        KeyboardUsage(usage: 0x37, name: ".", category: "Symbols"),
        KeyboardUsage(usage: 0x38, name: "/", category: "Symbols"),
        KeyboardUsage(usage: 0x39, name: "Caps Lock", category: "Editing"),
        KeyboardUsage(usage: 0x3a, name: "F1", category: "Function"),
        KeyboardUsage(usage: 0x3b, name: "F2", category: "Function"),
        KeyboardUsage(usage: 0x3c, name: "F3", category: "Function"),
        KeyboardUsage(usage: 0x3d, name: "F4", category: "Function"),
        KeyboardUsage(usage: 0x3e, name: "F5", category: "Function"),
        KeyboardUsage(usage: 0x3f, name: "F6", category: "Function"),
        KeyboardUsage(usage: 0x40, name: "F7", category: "Function"),
        KeyboardUsage(usage: 0x41, name: "F8", category: "Function"),
        KeyboardUsage(usage: 0x42, name: "F9", category: "Function"),
        KeyboardUsage(usage: 0x43, name: "F10", category: "Function"),
        KeyboardUsage(usage: 0x44, name: "F11", category: "Function"),
        KeyboardUsage(usage: 0x45, name: "F12", category: "Function"),
        KeyboardUsage(usage: 0x4f, name: "Right Arrow", category: "Navigation"),
        KeyboardUsage(usage: 0x50, name: "Left Arrow", category: "Navigation"),
        KeyboardUsage(usage: 0x51, name: "Down Arrow", category: "Navigation"),
        KeyboardUsage(usage: 0x52, name: "Up Arrow", category: "Navigation"),
        KeyboardUsage(usage: 0x68, name: "F13", category: "Function"),
        KeyboardUsage(usage: 0x69, name: "F14", category: "Function"),
        KeyboardUsage(usage: 0x6a, name: "F15", category: "Function"),
        KeyboardUsage(usage: 0x6b, name: "F16", category: "Function"),
        KeyboardUsage(usage: 0x6c, name: "F17", category: "Function"),
        KeyboardUsage(usage: 0x6d, name: "F18", category: "Function"),
        KeyboardUsage(usage: 0x6e, name: "F19", category: "Function"),
        KeyboardUsage(usage: 0x6f, name: "F20", category: "Function"),
        KeyboardUsage(usage: 0x70, name: "F21", category: "Function"),
        KeyboardUsage(usage: 0x71, name: "F22", category: "Function"),
        KeyboardUsage(usage: 0x72, name: "F23", category: "Function"),
        KeyboardUsage(usage: 0x73, name: "F24", category: "Function")
    ]

    public static let byUsage: [UInt8: KeyboardUsage] = Dictionary(uniqueKeysWithValues: all.map { ($0.usage, $0) })

    public static func usage(named raw: String) -> KeyboardUsage? {
        let normalized = normalize(raw)
        return all.first { normalize($0.name) == normalized }
    }

    public static func name(for usage: UInt8) -> String {
        byUsage[usage]?.name ?? "Keyboard usage \(Field75Hex.byte(usage))"
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
