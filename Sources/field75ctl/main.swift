import Field75Core
import Foundation

private struct CLIOptions {
    var command = "list"
    var registryID: UInt64?
    var sets: [String] = []
    var includeAll = false
    var json = false
    var confirm: String?
}

private func usage() -> Never {
    let text = """
    field75ctl - NuPhy Field75 G-key remap helper

    Commands:
      list [--json] [--all]
      targets
      readback --registry-id 0x...
      plan --registry-id 0x... --set G1=F14 [--set G2=Cmd+Shift+P]
      apply --registry-id 0x... --set G1=F14 --confirm FIELD75_WRITE_BLOCK38

    Target examples:
      F13
      F14
      Next Track
      Play/Pause
      Volume Up
      Cmd+Shift+P
      Space
      Restore
      Macro1

    Safety:
      plan and apply read block 0x38 first and overlay the requested G-key assignments.
      apply sends only the proven capture-sequence write path and requires the confirmation token.
      There is no firmware flashing, bootloader command, or arbitrary report sender.
    """
    fputs(text + "\n", stderr)
    exit(2)
}

private func parseOptions(_ args: [String]) -> CLIOptions {
    var options = CLIOptions()
    var index = 0
    if let first = args.first, ["list", "targets", "readback", "plan", "apply"].contains(first) {
        options.command = first
        index = 1
    }

    while index < args.count {
        switch args[index] {
        case "--registry-id":
            index += 1
            guard index < args.count, let value = Field75Hex.parseInteger(args[index]) else { usage() }
            options.registryID = value
        case "--set":
            index += 1
            guard index < args.count else { usage() }
            options.sets.append(args[index])
        case "--all":
            options.includeAll = true
        case "--json":
            options.json = true
        case "--confirm":
            index += 1
            guard index < args.count else { usage() }
            options.confirm = args[index]
        default:
            usage()
        }
        index += 1
    }

    if ["readback", "plan", "apply"].contains(options.command), options.registryID == nil {
        fputs("\(options.command) requires --registry-id.\n", stderr)
        usage()
    }
    if ["plan", "apply"].contains(options.command), options.sets.isEmpty {
        fputs("\(options.command) requires at least one --set G1=F14 assignment.\n", stderr)
        usage()
    }
    return options
}

private func parseAssignments(_ rawSets: [String]) throws -> [GKey: Field75Assignment] {
    var assignments: [GKey: Field75Assignment] = [:]
    for raw in rawSets {
        let parts = raw.split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2, let gKey = GKey.parse(parts[0]) else {
            throw Field75Error.invalidArgument("Expected --set G1=F14, got \(raw).")
        }
        assignments[gKey] = try Field75TargetParser.parse(parts[1], defaultMacroSlot: gKey.defaultMacroSlot)
    }
    return assignments
}

private func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

private func printDevices(_ devices: [Field75Device]) {
    for device in devices {
        let marker = device.isField75ControlCandidate ? "control" : "hid"
        print("\(device.registryIDHex) \(device.vendorIDHex):\(device.productIDHex) rev \(device.versionHex) \(marker) \(device.displayName) in:\(device.maxInputReportSize ?? 0) out:\(device.maxOutputReportSize ?? 0)")
    }
}

private func printTargets() {
    print("Hardware action targets:")
    for action in Field75HardwareActionCatalog.all {
        print("  \(action.name)")
    }
    print("")
    print("Keyboard targets:")
    for usage in KeyboardUsageCatalog.all {
        print("  \(usage.name)")
    }
    print("")
    print("Modifier syntax:")
    print("  Cmd+Shift+P")
    print("  Control+Option+F13")
    print("")
    print("Restore targets:")
    print("  Restore")
    print("  Macro1 ... Macro8")
}

private func printReadback(_ readback: Field75Readback) {
    print("Device \(readback.device.registryIDHex) \(readback.device.displayName)")
    print("Received \(readback.frames.count) block 0x38 frame(s); decoded \(readback.assignments.count) assignments.")
    for gKey in GKey.allCases {
        let entry = readback.assignments.first { $0.index == gKey.assignmentIndex }
        print("\(gKey.rawValue) index \(gKey.assignmentIndex) offset \(Field75Hex.word(UInt16(gKey.byteOffset))) \(entry?.rawHex ?? "?") \(entry?.description ?? "unknown")")
    }
}

private func printPlan(_ plan: Field75RemapPlan, dryRun: Bool) {
    print("\(dryRun ? "Dry-run generated" : "Generated") \(plan.frameCount) capture-sequence frame(s).")
    for change in plan.changes {
        print("\(change.gKey.rawValue) offset \(change.offsetHex): \(change.before.rawHex) \(change.before.description) -> \(change.after.rawHex) \(change.after.description)")
    }
    for validation in plan.validations {
        let status = validation.valid ? "valid" : "invalid"
        print("frame op \(Field75Hex.byte(validation.op)) block \(Field75Hex.byte(validation.block)) offset \(validation.offsetHex) checksum \(validation.checksumHex): \(status)")
        if let reason = validation.reason {
            print("  \(reason)")
        }
    }
}

private let options = parseOptions(Array(CommandLine.arguments.dropFirst()))
private let client = Field75HIDClient()

do {
    switch options.command {
    case "list":
        let devices = try client.listDevices(includeAll: options.includeAll)
        if options.json {
            try printJSON(devices)
        } else {
            printDevices(devices)
        }
    case "targets":
        printTargets()
    case "readback":
        let readback = try client.readBlock38(registryID: options.registryID!)
        if options.json {
            try printJSON(readback)
        } else {
            printReadback(readback)
        }
    case "plan", "apply":
        let requestedAssignments = try parseAssignments(options.sets)
        var assignments = Dictionary(uniqueKeysWithValues: GKey.allCases.map { ($0, Field75Assignment.macroSlot($0.defaultMacroSlot)) })
        assignments.merge(requestedAssignments) { _, requested in requested }
        let readback = try client.readBlock38(registryID: options.registryID!)
        let plan = try Field75RemapPlanner.makePlan(baseBlock38Memory: readback.block38Memory, assignments: assignments)
        if options.command == "plan" {
            if options.json {
                try printJSON(plan)
            } else {
                printPlan(plan, dryRun: true)
                print("No HID write was sent. Use apply with --confirm FIELD75_WRITE_BLOCK38 to write.")
            }
        } else {
            guard options.confirm == "FIELD75_WRITE_BLOCK38" else {
                throw Field75Error.invalidArgument("Refusing write without --confirm FIELD75_WRITE_BLOCK38.")
            }
            printPlan(plan, dryRun: false)
            let result = try client.applyRemapPlan(plan, registryID: options.registryID!)
            print("Sent \(result.sentFrameCount) frame(s). Received \(result.echoes.count) echo/status frame(s).")
        }
    default:
        usage()
    }
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
