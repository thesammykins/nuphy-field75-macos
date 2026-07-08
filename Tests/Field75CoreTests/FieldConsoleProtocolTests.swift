import Field75Core
import XCTest

final class FieldConsoleProtocolTests: XCTestCase {
    func testProfileReportChecksumMatchesCapture() throws {
        let report = FieldConsoleProtocol.makeReport(
            op: 0x15,
            block: 0x1e,
            offset: 0x0000,
            payload: FieldConsoleProtocol.profilePayload
        )

        let decoded = try XCTUnwrap(FieldConsoleProtocol.decode(report))
        XCTAssertEqual(decoded.checksumExpected, 0x0540)
        XCTAssertTrue(decoded.checksumValid)
        XCTAssertEqual(decoded.op, 0x15)
        XCTAssertEqual(decoded.block, 0x1e)
    }

    func testCaptureSequenceShapeAndValidation() throws {
        let memory = Field75RemapPlanner.templateWithDefaultMacroSlots()
        let reports = Field75RemapPlanner.captureSequenceReports(block38Memory: memory)
        let decoded = reports.compactMap(FieldConsoleProtocol.decode)

        XCTAssertEqual(reports.count, 17)
        XCTAssertEqual(decoded.map(\.op), [0x03, 0x01, 0x15, 0x02, 0x03, 0x01, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x09, 0x02])
        XCTAssertEqual(decoded[6].block, 0x38)
        XCTAssertEqual(decoded[15].block, 0x06)
        XCTAssertTrue(reports.map(FieldConsoleProtocol.validateGeneratedReport).allSatisfy(\.valid))
    }

    func testG1F14OverlayUsesLiveAssignmentOffset() throws {
        let memory = Field75RemapPlanner.templateWithDefaultMacroSlots()
        let plan = try Field75RemapPlanner.makePlan(
            baseBlock38Memory: memory,
            assignments: [.g1: .keyboard(usage: 0x69)]
        )

        let change = try XCTUnwrap(plan.changes.first)
        XCTAssertEqual(change.gKey, .g1)
        XCTAssertEqual(change.offsetHex, "0x0123")
        XCTAssertEqual(change.before.rawHex, "0xd0a201")
        XCTAssertEqual(change.after.rawHex, "0x200069")

        let blockFrame = try XCTUnwrap(plan.reports.first { report in
            guard let decoded = FieldConsoleProtocol.decode(report) else { return false }
            return decoded.op == 0x09 && decoded.block == 0x38 && decoded.offset == 0x0118
        })
        let localOffset = GKey.g1.byteOffset - 0x0118
        XCTAssertEqual(blockFrame[FieldConsoleProtocol.dataOffset + localOffset], 0x20)
        XCTAssertEqual(blockFrame[FieldConsoleProtocol.dataOffset + localOffset + 1], 0x00)
        XCTAssertEqual(blockFrame[FieldConsoleProtocol.dataOffset + localOffset + 2], 0x69)
    }

    func testKeyboardTargetParserSupportsMacModifiers() throws {
        let assignment = try Field75TargetParser.parse("Cmd+Shift+P")
        XCTAssertEqual(assignment.rawHex, "0x200a13")
        XCTAssertEqual(assignment.description, "Cmd+Shift+P")
    }

    func testHardwareActionEncodingMatchesFieldConsoleConsumerUsageTable() throws {
        XCTAssertEqual(Field75Assignment.hardwareAction(usage: 0x00b5).rawHex, "0x30b500")
        XCTAssertEqual(Field75Assignment.hardwareAction(usage: 0x00cd).rawHex, "0x30cd00")

        let nextTrack = try Field75TargetParser.parse("Next Track")
        XCTAssertEqual(nextTrack.rawHex, "0x30b500")
        XCTAssertEqual(nextTrack.description, "Next Track")

        let decoded = Field75Assignment.decode(index: 97, raw: [0x30, 0xb5, 0x00])
        XCTAssertEqual(decoded.assignmentClass, "consumer_control")
        XCTAssertEqual(decoded.description, "Next Track")
    }
}
