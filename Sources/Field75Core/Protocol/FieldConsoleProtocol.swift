import Foundation

public struct FieldConsoleDecodedFrame: Codable, Hashable, Sendable {
    public let reportID: UInt8
    public let checksumExpected: UInt16
    public let checksumComputed: UInt16
    public let checksumValid: Bool
    public let op: UInt8
    public let block: UInt8
    public let offset: UInt16
    public let reserved: UInt8
    public let commandName: String
    public let dataHex: String
    public let rawHex: String

    public var opHex: String { Field75Hex.byte(op) }
    public var blockHex: String { Field75Hex.byte(block) }
    public var offsetHex: String { Field75Hex.word(offset) }
    public var checksumHex: String { Field75Hex.word(checksumExpected) }
}

public struct FieldConsoleFrameValidation: Codable, Hashable, Sendable {
    public let valid: Bool
    public let reason: String?
    public let op: UInt8
    public let block: UInt8
    public let offset: UInt16
    public let checksum: UInt16

    public var offsetHex: String { Field75Hex.word(offset) }
    public var checksumHex: String { Field75Hex.word(checksum) }
}

public enum FieldConsoleProtocol {
    public static let reportID: UInt8 = 0x04
    public static let reportLength = 64
    public static let dataOffset = 8
    public static let payloadLength = 56
    public static let block38ByteCount = 0x01f8
    public static let block38Offsets = Array(stride(from: 0x0000, through: 0x01c0, by: payloadLength))

    public static let profilePayload = Field75Hex.bytes(from: """
    aa551e00010055007300650072007300120002006f006e008a2c00000a2c0000000000000000000000000000000000000000000000000000
    """)

    public static let block06TailPayload = Field75Hex.bytes(from: """
    000000ffffffffffffffffffffff000000000000000000ffffff000000000000000000000000000000ffffff000000000000ffffff000000
    """)

    private static let commandNames: [UInt8: String] = [
        0x01: "handshake/status query",
        0x02: "commit/status/transition",
        0x03: "device/status query",
        0x05: "metadata/status query candidate",
        0x07: "block read request/readback",
        0x09: "state-changing block write",
        0x15: "profile/path or metadata write",
        0x1b: "secondary block read candidate"
    ]

    public static func makeReport(op: UInt8, block: UInt8, offset: UInt16, payload: [UInt8] = []) -> Data {
        precondition(payload.count <= payloadLength)
        var report = [UInt8](repeating: 0, count: reportLength)
        report[0] = reportID
        report[3] = op
        report[4] = block
        report[5] = UInt8(offset & 0x00ff)
        report[6] = UInt8((offset >> 8) & 0x00ff)
        for (index, byte) in payload.enumerated() {
            report[dataOffset + index] = byte
        }
        let checksum = checksum(for: report)
        report[1] = UInt8(checksum & 0x00ff)
        report[2] = UInt8((checksum >> 8) & 0x00ff)
        return Data(report)
    }

    public static func checksum(for report: [UInt8]) -> UInt16 {
        report[3..<reportLength].reduce(0) { partial, byte in
            (partial + UInt16(byte)) & 0xffff
        }
    }

    public static func block38ReadbackReports() -> [Data] {
        block38Offsets.map { offset in
            makeReport(op: 0x07, block: 0x38, offset: UInt16(offset))
        }
    }

    public static func decode(_ report: Data) -> FieldConsoleDecodedFrame? {
        guard report.count >= dataOffset, report.first == reportID else {
            return nil
        }
        let expected = UInt16(report[1]) | (UInt16(report[2]) << 8)
        let computed = report[3..<min(report.count, reportLength)].reduce(0) { partial, byte in
            (partial + UInt16(byte)) & 0xffff
        }
        let op = report[3]
        let block = report[4]
        let offset = UInt16(report[5]) | (UInt16(report[6]) << 8)
        let payload = report.count > dataOffset ? Data(report[dataOffset..<report.count]) : Data()
        return FieldConsoleDecodedFrame(
            reportID: report[0],
            checksumExpected: expected,
            checksumComputed: computed,
            checksumValid: expected == computed,
            op: op,
            block: block,
            offset: offset,
            reserved: report[7],
            commandName: commandNames[op] ?? "unknown",
            dataHex: Field75Hex.string(payload),
            rawHex: Field75Hex.string(report)
        )
    }

    public static func validateGeneratedReport(_ report: Data) -> FieldConsoleFrameValidation {
        guard report.count == reportLength else {
            return FieldConsoleFrameValidation(valid: false, reason: "report is not 64 bytes", op: 0, block: 0, offset: 0, checksum: 0)
        }
        guard report[0] == reportID else {
            return FieldConsoleFrameValidation(valid: false, reason: "report ID is not 0x04", op: 0, block: 0, offset: 0, checksum: 0)
        }
        guard let decoded = decode(report), decoded.checksumValid else {
            return FieldConsoleFrameValidation(valid: false, reason: "checksum is invalid", op: report[3], block: report[4], offset: UInt16(report[5]) | (UInt16(report[6]) << 8), checksum: UInt16(report[1]) | (UInt16(report[2]) << 8))
        }

        let op = decoded.op
        let block = decoded.block
        let offset = decoded.offset
        let payload = Array(report[dataOffset..<reportLength])
        let zeroPayload = [UInt8](repeating: 0, count: payloadLength)
        let checksum = decoded.checksumExpected

        let valid: Bool
        if op == 0x09 && block == 0x38 && block38Offsets.contains(Int(offset)) {
            valid = true
        } else if op == 0x09 && block == 0x06 && offset == 0x01f8 && payload == block06TailPayload {
            valid = true
        } else if op == 0x02 && block == 0x00 && offset == 0x0000 && payload == zeroPayload {
            valid = true
        } else if op == 0x01 && block == 0x00 && offset == 0x0000 && payload == zeroPayload {
            valid = true
        } else if op == 0x03 && block == 0x22 && offset == 0x0000 && payload == zeroPayload {
            valid = true
        } else if op == 0x15 && block == 0x1e && offset == 0x0000 && payload == profilePayload {
            valid = true
        } else {
            valid = false
        }

        return FieldConsoleFrameValidation(
            valid: valid,
            reason: valid ? nil : "report op=\(decoded.opHex) block=\(decoded.blockHex) offset=\(decoded.offsetHex) is not whitelisted",
            op: op,
            block: block,
            offset: offset,
            checksum: checksum
        )
    }

    public static func reconstructBlock38(from frames: [FieldConsoleDecodedFrame]) -> [UInt8] {
        var memory = [UInt8](repeating: 0xff, count: block38ByteCount)
        for frame in frames where frame.op == 0x07 && frame.block == 0x38 {
            let baseOffset = Int(frame.offset)
            let bytes = Field75Hex.bytes(from: frame.dataHex)
            for (index, byte) in bytes.enumerated() where baseOffset + index < memory.count {
                memory[baseOffset + index] = byte
            }
        }
        return memory
    }

    public static func assignmentTable(from block38Memory: [UInt8]) -> [Field75AssignmentEntry] {
        let entryCount = block38Memory.count / 3
        return (0..<entryCount).compactMap { index in
            let offset = index * 3
            guard offset + 2 < block38Memory.count else {
                return nil
            }
            return Field75Assignment.decode(index: index, raw: Array(block38Memory[offset..<(offset + 3)]))
        }
    }
}
