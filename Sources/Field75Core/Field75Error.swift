import Foundation

public enum Field75Error: Error, LocalizedError, Equatable {
    case invalidArgument(String)
    case deviceNotFound(UInt64)
    case unsuitableInterface(String)
    case hidOpenFailed(UInt32)
    case hidSetReportFailed(UInt32, sentCount: Int)
    case incompleteReadback(received: Int)
    case invalidBlock38Template(String)
    case invalidGeneratedFrame(String)

    public var errorDescription: String? {
        switch self {
        case .invalidArgument(let message):
            message
        case .deviceNotFound(let registryID):
            "No matching Field75 HID interface found for registry ID \(Field75Hex.number(registryID))."
        case .unsuitableInterface(let message):
            message
        case .hidOpenFailed(let code):
            "IOHIDDeviceOpen failed: 0x\(String(code, radix: 16))."
        case .hidSetReportFailed(let code, let sentCount):
            "IOHIDDeviceSetReport failed after \(sentCount) frame(s): 0x\(String(code, radix: 16))."
        case .incompleteReadback(let received):
            "Readback returned \(received) block frame(s); expected 9."
        case .invalidBlock38Template(let message):
            message
        case .invalidGeneratedFrame(let message):
            message
        }
    }
}
