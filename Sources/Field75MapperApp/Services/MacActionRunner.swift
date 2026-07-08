import ApplicationServices
import CoreGraphics
import Foundation

final class MacActionRunner {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var actionsByKeyCode: [CGKeyCode: MacMacroAction] = [:]

    var isRunning: Bool {
        eventTap != nil
    }

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start(actionsByCarrierUsage: [UInt8: MacMacroAction]) throws {
        stop()
        actionsByKeyCode = Dictionary(uniqueKeysWithValues: actionsByCarrierUsage.compactMap { usage, action in
            guard let keyCode = CarrierKeyMap.virtualKeyCode(forHIDUsage: usage) else {
                return nil
            }
            return (keyCode, action)
        })
        guard !actionsByKeyCode.isEmpty else {
            return
        }
        guard isAccessibilityTrusted else {
            requestAccessibilityPermission()
            throw Field75RunnerError.accessibilityRequired
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: actionRunnerCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw Field75RunnerError.eventTapFailed
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handle(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard let action = actionsByKeyCode[keyCode] else {
            return Unmanaged.passUnretained(event)
        }

        MacMacroExecutor.run(action)
        return nil
    }
}

enum Field75RunnerError: LocalizedError {
    case accessibilityRequired
    case eventTapFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Accessibility permission is required for the Mac Macro runner."
        case .eventTapFailed:
            "Unable to create a keyboard event tap for the Mac Macro runner."
        }
    }
}

private let actionRunnerCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let runner = Unmanaged<MacActionRunner>.fromOpaque(userInfo).takeUnretainedValue()
    return runner.handle(event, type: type)
}
