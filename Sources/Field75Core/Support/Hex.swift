import Foundation

public enum Field75Hex {
    public static func string(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    public static func string(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    public static func byte(_ value: UInt8) -> String {
        "0x" + String(format: "%02x", value)
    }

    public static func word(_ value: UInt16) -> String {
        "0x" + String(format: "%04x", value)
    }

    public static func number(_ value: UInt64) -> String {
        "0x" + String(value, radix: 16)
    }

    public static func bytes(from value: String) -> [UInt8] {
        let cleaned = value
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\t", with: "")

        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
            if let byte = UInt8(cleaned[index..<next], radix: 16) {
                bytes.append(byte)
            }
            index = next
        }
        return bytes
    }

    public static func parseInteger(_ raw: String) -> UInt64? {
        if raw.lowercased().hasPrefix("0x") {
            return UInt64(raw.dropFirst(2), radix: 16)
        }
        return UInt64(raw, radix: 10)
    }
}
