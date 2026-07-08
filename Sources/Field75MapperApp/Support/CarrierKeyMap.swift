import CoreGraphics
import Field75Core
import Foundation

enum CarrierKeyMap {
    static let supportedUsages: [UInt8] = [
        0x68, 0x69, 0x6a, 0x6b, 0x6c, 0x6d, 0x6e, 0x6f
    ]

    static func virtualKeyCode(forHIDUsage usage: UInt8) -> CGKeyCode? {
        switch usage {
        case 0x68: 105
        case 0x69: 107
        case 0x6a: 113
        case 0x6b: 106
        case 0x6c: 64
        case 0x6d: 79
        case 0x6e: 80
        case 0x6f: 90
        default: nil
        }
    }
}
