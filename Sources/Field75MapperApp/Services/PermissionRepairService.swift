import Foundation

enum PermissionRepairService {
    private static let bundleIdentifier = "dev.samanthamyers.Field75Mapper"

    static func resetPrivacyPermissions() throws {
        try runTCCReset(service: "ListenEvent")
        try runTCCReset(service: "Accessibility")
    }

    private static func runTCCReset(service: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", service, bundleIdentifier]

        let errorPipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PermissionRepairError.resetFailed(service: service, detail: message ?? "tccutil exited with \(process.terminationStatus)")
        }
    }
}

enum PermissionRepairError: LocalizedError {
    case resetFailed(service: String, detail: String)

    var errorDescription: String? {
        switch self {
        case let .resetFailed(service, detail):
            "Could not reset \(service) permission: \(detail)"
        }
    }
}
