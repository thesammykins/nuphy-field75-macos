import Foundation

public struct HIDUsagePair: Codable, Hashable, Sendable {
    public let usagePage: UInt64
    public let usage: UInt64

    public init(usagePage: UInt64, usage: UInt64) {
        self.usagePage = usagePage
        self.usage = usage
    }
}

public struct Field75Device: Codable, Hashable, Identifiable, Sendable {
    public let registryID: UInt64
    public let transport: String?
    public let vendorID: UInt64?
    public let productID: UInt64?
    public let versionNumber: UInt64?
    public let locationID: UInt64?
    public let manufacturer: String?
    public let product: String?
    public let serialNumber: String?
    public let primaryUsagePage: UInt64?
    public let primaryUsage: UInt64?
    public let maxInputReportSize: UInt64?
    public let maxOutputReportSize: UInt64?
    public let maxFeatureReportSize: UInt64?
    public let reportDescriptorLength: Int?
    public let reportDescriptorSHA256: String?
    public let usagePairs: [HIDUsagePair]

    public var id: UInt64 { registryID }
    public var registryIDHex: String { Field75Hex.number(registryID) }
    public var vendorIDHex: String { vendorID.map(Field75Hex.number) ?? "?" }
    public var productIDHex: String { productID.map(Field75Hex.number) ?? "?" }
    public var versionHex: String { versionNumber.map(Field75Hex.number) ?? "?" }
    public var locationIDHex: String { locationID.map(Field75Hex.number) ?? "?" }
    public var displayName: String { product ?? "Unknown HID Device" }

    public var isField75ControlCandidate: Bool {
        vendorID == Field75Constants.vendorID &&
            productID == Field75Constants.productID &&
            (maxInputReportSize ?? 0) >= UInt64(FieldConsoleProtocol.reportLength) &&
            (maxOutputReportSize ?? 0) >= UInt64(FieldConsoleProtocol.reportLength)
    }
}

public enum Field75Constants {
    public static let vendorID: UInt64 = 0x05ac
    public static let productID: UInt64 = 0x024f
    public static let expectedRevision: UInt64 = 0x0108
}
