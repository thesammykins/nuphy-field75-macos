import CryptoKit
import Foundation
import IOKit.hid

public struct Field75Readback: Codable, Hashable, Sendable {
    public let device: Field75Device
    public let frames: [FieldConsoleDecodedFrame]
    public let block38Memory: [UInt8]
    public let assignments: [Field75AssignmentEntry]
}

public struct Field75WriteResult: Codable, Hashable, Sendable {
    public let device: Field75Device
    public let sentFrameCount: Int
    public let echoes: [FieldConsoleDecodedFrame]
}

public final class Field75HIDClient {
    public init() {}

    public func listDevices(includeAll: Bool = false) throws -> [Field75Device] {
        try rawDevices(includeAll: includeAll)
            .map(deviceInfo(for:))
            .sorted { $0.registryID < $1.registryID }
    }

    public func readBlock38(registryID: UInt64, seconds: TimeInterval = 1.0) throws -> Field75Readback {
        let device = try rawDevice(registryID: registryID)
        let info = deviceInfo(for: device)
        try validateControlInterface(info)

        let maxInputLength = Int(info.maxInputReportSize ?? UInt64(FieldConsoleProtocol.reportLength))
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxInputLength)
        buffer.initialize(repeating: 0, count: maxInputLength)
        let state = FieldConsoleCaptureState(filterOp: 0x07, filterBlock: 0x38)
        let statePointer = Unmanaged.passRetained(state).toOpaque()
        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            buffer.deallocate()
            Unmanaged<FieldConsoleCaptureState>.fromOpaque(statePointer).release()
            throw Field75Error.hidOpenFailed(UInt32(bitPattern: openResult))
        }

        defer {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            buffer.deallocate()
            Unmanaged<FieldConsoleCaptureState>.fromOpaque(statePointer).release()
        }

        IOHIDDeviceRegisterInputReportCallback(device, buffer, maxInputLength, fieldConsoleCaptureCallback, statePointer)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        var sent = 0
        for report in FieldConsoleProtocol.block38ReadbackReports() {
            try send(report, to: device, sentCount: sent)
            sent += 1
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.05, false)
        }

        runLoop(until: Date().addingTimeInterval(seconds), stopWhen: { state.frames.count >= FieldConsoleProtocol.block38Offsets.count })
        guard state.frames.count == FieldConsoleProtocol.block38Offsets.count else {
            throw Field75Error.incompleteReadback(received: state.frames.count)
        }

        let memory = FieldConsoleProtocol.reconstructBlock38(from: state.frames)
        return Field75Readback(
            device: info,
            frames: state.frames,
            block38Memory: memory,
            assignments: FieldConsoleProtocol.assignmentTable(from: memory)
        )
    }

    public func applyRemapPlan(
        _ plan: Field75RemapPlan,
        registryID: UInt64,
        echoSeconds: TimeInterval = 0.35
    ) throws -> Field75WriteResult {
        guard plan.isValid else {
            let reason = plan.validations.first(where: { !$0.valid })?.reason ?? "plan contains invalid frames"
            throw Field75Error.invalidGeneratedFrame(reason)
        }

        let device = try rawDevice(registryID: registryID)
        let info = deviceInfo(for: device)
        try validateControlInterface(info)

        let maxInputLength = Int(info.maxInputReportSize ?? UInt64(FieldConsoleProtocol.reportLength))
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxInputLength)
        buffer.initialize(repeating: 0, count: maxInputLength)
        let state = FieldConsoleCaptureState()
        let statePointer = Unmanaged.passRetained(state).toOpaque()
        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            buffer.deallocate()
            Unmanaged<FieldConsoleCaptureState>.fromOpaque(statePointer).release()
            throw Field75Error.hidOpenFailed(UInt32(bitPattern: openResult))
        }

        defer {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            buffer.deallocate()
            Unmanaged<FieldConsoleCaptureState>.fromOpaque(statePointer).release()
        }

        IOHIDDeviceRegisterInputReportCallback(device, buffer, maxInputLength, fieldConsoleCaptureCallback, statePointer)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        var sent = 0
        for report in plan.reports {
            try send(report, to: device, sentCount: sent)
            sent += 1
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.08, false)
        }
        runLoop(until: Date().addingTimeInterval(echoSeconds))
        return Field75WriteResult(device: info, sentFrameCount: sent, echoes: state.frames)
    }

    private func validateControlInterface(_ info: Field75Device) throws {
        guard (info.maxInputReportSize ?? 0) >= UInt64(FieldConsoleProtocol.reportLength),
              (info.maxOutputReportSize ?? 0) >= UInt64(FieldConsoleProtocol.reportLength) else {
            throw Field75Error.unsuitableInterface("Selected interface does not expose 64-byte input/output reports.")
        }
    }

    private func send(_ report: Data, to device: IOHIDDevice, sentCount: Int) throws {
        let sendResult = report.withUnsafeBytes { rawBuffer -> IOReturn in
            let pointer = rawBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                CFIndex(FieldConsoleProtocol.reportID),
                pointer,
                report.count
            )
        }
        guard sendResult == kIOReturnSuccess else {
            throw Field75Error.hidSetReportFailed(UInt32(bitPattern: sendResult), sentCount: sentCount)
        }
    }

    private func rawDevice(registryID: UInt64) throws -> IOHIDDevice {
        guard let device = try rawDevices(includeAll: false).first(where: { deviceRegistryID(for: $0) == registryID }) else {
            throw Field75Error.deviceNotFound(registryID)
        }
        return device
    }

    private func rawDevices(includeAll: Bool) throws -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        if includeAll {
            IOHIDManagerSetDeviceMatching(manager, nil)
        } else {
            let matching: [String: Any] = [
                kIOHIDVendorIDKey as String: Field75Constants.vendorID,
                kIOHIDProductIDKey as String: Field75Constants.productID
            ]
            IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        }

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw Field75Error.hidOpenFailed(UInt32(bitPattern: result))
        }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }
        return deviceSet.sorted { deviceRegistryID(for: $0) < deviceRegistryID(for: $1) }
    }
}

private final class FieldConsoleCaptureState {
    let filterOp: UInt8?
    let filterBlock: UInt8?
    var frames: [FieldConsoleDecodedFrame] = []

    init(filterOp: UInt8? = nil, filterBlock: UInt8? = nil) {
        self.filterOp = filterOp
        self.filterBlock = filterBlock
    }
}

private let fieldConsoleCaptureCallback: IOHIDReportCallback = { context, result, _, _, _, report, reportLength in
    guard result == kIOReturnSuccess, let context else {
        return
    }
    let state = Unmanaged<FieldConsoleCaptureState>.fromOpaque(context).takeUnretainedValue()
    let data = Data(bytes: report, count: reportLength)
    guard let frame = FieldConsoleProtocol.decode(data) else {
        return
    }
    if let filterOp = state.filterOp, frame.op != filterOp {
        return
    }
    if let filterBlock = state.filterBlock, frame.block != filterBlock {
        return
    }
    state.frames.append(frame)
}

private func runLoop(until deadline: Date, stopWhen: (() -> Bool)? = nil) {
    while Date() < deadline {
        if stopWhen?() == true {
            return
        }
        let remaining = max(0.05, min(0.25, deadline.timeIntervalSinceNow))
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, remaining, false)
    }
}

private func numberProperty(_ device: IOHIDDevice, _ key: CFString) -> UInt64? {
    guard let value = IOHIDDeviceGetProperty(device, key) else {
        return nil
    }
    if let number = value as? NSNumber {
        return number.uint64Value
    }
    if let string = value as? String {
        return Field75Hex.parseInteger(string)
    }
    return nil
}

private func stringProperty(_ device: IOHIDDevice, _ key: CFString) -> String? {
    guard let value = IOHIDDeviceGetProperty(device, key) else {
        return nil
    }
    if let string = value as? String {
        return string
    }
    if let number = value as? NSNumber {
        return Field75Hex.number(number.uint64Value)
    }
    return String(describing: value)
}

private func dataProperty(_ device: IOHIDDevice, _ key: CFString) -> Data? {
    guard let value = IOHIDDeviceGetProperty(device, key) else {
        return nil
    }
    if let data = value as? Data {
        return data
    }
    if CFGetTypeID(value) == CFDataGetTypeID() {
        return value as? Data
    }
    return nil
}

private func deviceRegistryID(for device: IOHIDDevice) -> UInt64 {
    let service = IOHIDDeviceGetService(device)
    var registryID: UInt64 = 0
    let result = IORegistryEntryGetRegistryEntryID(service, &registryID)
    return result == KERN_SUCCESS ? registryID : 0
}

private func usagePairs(for device: IOHIDDevice) -> [HIDUsagePair] {
    guard let rawPairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString),
          let pairs = rawPairs as? [[String: Any]] else {
        return []
    }

    return pairs.compactMap { pair in
        let page = (pair[kIOHIDDeviceUsagePageKey as String] as? NSNumber)?.uint64Value
        let usage = (pair[kIOHIDDeviceUsageKey as String] as? NSNumber)?.uint64Value
        guard let page, let usage else {
            return nil
        }
        return HIDUsagePair(usagePage: page, usage: usage)
    }
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func deviceInfo(for device: IOHIDDevice) -> Field75Device {
    let descriptor = dataProperty(device, kIOHIDReportDescriptorKey as CFString)
    return Field75Device(
        registryID: deviceRegistryID(for: device),
        transport: stringProperty(device, kIOHIDTransportKey as CFString),
        vendorID: numberProperty(device, kIOHIDVendorIDKey as CFString),
        productID: numberProperty(device, kIOHIDProductIDKey as CFString),
        versionNumber: numberProperty(device, kIOHIDVersionNumberKey as CFString),
        locationID: numberProperty(device, kIOHIDLocationIDKey as CFString),
        manufacturer: stringProperty(device, kIOHIDManufacturerKey as CFString),
        product: stringProperty(device, kIOHIDProductKey as CFString),
        serialNumber: stringProperty(device, kIOHIDSerialNumberKey as CFString),
        primaryUsagePage: numberProperty(device, kIOHIDPrimaryUsagePageKey as CFString),
        primaryUsage: numberProperty(device, kIOHIDPrimaryUsageKey as CFString),
        maxInputReportSize: numberProperty(device, kIOHIDMaxInputReportSizeKey as CFString),
        maxOutputReportSize: numberProperty(device, kIOHIDMaxOutputReportSizeKey as CFString),
        maxFeatureReportSize: numberProperty(device, kIOHIDMaxFeatureReportSizeKey as CFString),
        reportDescriptorLength: descriptor?.count,
        reportDescriptorSHA256: descriptor.map(sha256Hex),
        usagePairs: usagePairs(for: device)
    )
}
