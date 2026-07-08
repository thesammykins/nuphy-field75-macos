import Foundation

public struct Field75RemapPlan: Codable, Hashable, Sendable {
    public let reports: [Data]
    public let validations: [FieldConsoleFrameValidation]
    public let changes: [GKeyAssignmentChange]

    public var frameCount: Int {
        reports.count
    }

    public var isValid: Bool {
        validations.allSatisfy(\.valid)
    }

    public var decodedFrames: [FieldConsoleDecodedFrame] {
        reports.compactMap(FieldConsoleProtocol.decode)
    }
}

public enum Field75RemapPlanner {
    public static func makePlan(
        baseBlock38Memory: [UInt8],
        assignments: [GKey: Field75Assignment]
    ) throws -> Field75RemapPlan {
        guard baseBlock38Memory.count == FieldConsoleProtocol.block38ByteCount else {
            throw Field75Error.invalidBlock38Template("Block 0x38 template must be exactly \(FieldConsoleProtocol.block38ByteCount) bytes.")
        }

        var memory = baseBlock38Memory
        var changes: [GKeyAssignmentChange] = []

        for gKey in GKey.allCases {
            guard let assignment = assignments[gKey] else {
                continue
            }
            let offset = gKey.byteOffset
            guard offset + 2 < memory.count else {
                throw Field75Error.invalidBlock38Template("\(gKey.rawValue) offset \(offset) is outside block 0x38.")
            }
            let beforeBytes = Array(memory[offset..<(offset + 3)])
            let before = Field75Assignment(bytes: beforeBytes, description: Field75Assignment.decode(index: gKey.assignmentIndex, raw: beforeBytes).description)
            memory.replaceSubrange(offset..<(offset + 3), with: assignment.bytes)
            changes.append(GKeyAssignmentChange(gKey: gKey, before: before, after: assignment))
        }

        let reports = captureSequenceReports(block38Memory: memory)
        let validations = reports.map(FieldConsoleProtocol.validateGeneratedReport)
        guard let invalid = validations.first(where: { !$0.valid }) else {
            return Field75RemapPlan(reports: reports, validations: validations, changes: changes)
        }
        throw Field75Error.invalidGeneratedFrame(invalid.reason ?? "Generated frame failed validation.")
    }

    public static func captureSequenceReports(block38Memory: [UInt8]) -> [Data] {
        precondition(block38Memory.count == FieldConsoleProtocol.block38ByteCount)
        var reports: [Data] = []
        reports.append(FieldConsoleProtocol.makeReport(op: 0x03, block: 0x22, offset: 0x0000))
        reports.append(FieldConsoleProtocol.makeReport(op: 0x01, block: 0x00, offset: 0x0000))
        reports.append(FieldConsoleProtocol.makeReport(op: 0x15, block: 0x1e, offset: 0x0000, payload: FieldConsoleProtocol.profilePayload))
        reports.append(FieldConsoleProtocol.makeReport(op: 0x02, block: 0x00, offset: 0x0000))
        reports.append(FieldConsoleProtocol.makeReport(op: 0x03, block: 0x22, offset: 0x0000))
        reports.append(FieldConsoleProtocol.makeReport(op: 0x01, block: 0x00, offset: 0x0000))

        for offset in FieldConsoleProtocol.block38Offsets {
            let end = offset + FieldConsoleProtocol.payloadLength
            let payload = Array(block38Memory[offset..<end])
            reports.append(FieldConsoleProtocol.makeReport(op: 0x09, block: 0x38, offset: UInt16(offset), payload: payload))
        }

        reports.append(FieldConsoleProtocol.makeReport(op: 0x09, block: 0x06, offset: 0x01f8, payload: FieldConsoleProtocol.block06TailPayload))
        reports.append(FieldConsoleProtocol.makeReport(op: 0x02, block: 0x00, offset: 0x0000))
        return reports
    }

    public static func templateWithDefaultMacroSlots() -> [UInt8] {
        var memory = [UInt8](repeating: 0xff, count: FieldConsoleProtocol.block38ByteCount)
        for gKey in GKey.allCases {
            memory.replaceSubrange(gKey.byteOffset..<(gKey.byteOffset + 3), with: Field75Assignment.macroSlot(gKey.defaultMacroSlot).bytes)
        }
        return memory
    }
}
