import Foundation

public enum GKey: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case g1 = "G1"
    case g2 = "G2"
    case g3 = "G3"
    case g4 = "G4"
    case g5 = "G5"
    case g6 = "G6"
    case g7 = "G7"
    case g8 = "G8"

    public var id: String { rawValue }

    public var assignmentIndex: Int {
        switch self {
        case .g1: 97
        case .g2: 98
        case .g3: 99
        case .g4: 100
        case .g5: 29
        case .g6: 35
        case .g7: 47
        case .g8: 53
        }
    }

    public var byteOffset: Int {
        assignmentIndex * 3
    }

    public var defaultMacroSlot: UInt8 {
        switch self {
        case .g1: 1
        case .g2: 2
        case .g3: 3
        case .g4: 4
        case .g5: 5
        case .g6: 6
        case .g7: 7
        case .g8: 8
        }
    }

    public var defaultCarrierUsage: UInt8 {
        switch self {
        case .g1: 0x68
        case .g2: 0x69
        case .g3: 0x6a
        case .g4: 0x6b
        case .g5: 0x6c
        case .g6: 0x6d
        case .g7: 0x6e
        case .g8: 0x6f
        }
    }

    public static func parse(_ raw: String) -> GKey? {
        let normalized = raw.uppercased()
        return allCases.first { $0.rawValue == normalized }
    }
}

public struct GKeyAssignmentChange: Codable, Hashable, Sendable {
    public let gKey: GKey
    public let before: Field75Assignment
    public let after: Field75Assignment

    public var offsetHex: String {
        Field75Hex.word(UInt16(gKey.byteOffset))
    }
}
