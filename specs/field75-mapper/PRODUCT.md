# Field75 Mapper Product Spec

## Problem

NuPhy Field75 owners on macOS do not have a native tool for remapping the G macro keys. The official Field Console is Windows-only, and the keyboard uses a custom HID protocol rather than QMK or NuPhy.IO.

## Goals

- Provide a small native macOS app for remapping G1-G8 without running Windows.
- Keep persistent remaps for normal keyboard outputs on the keyboard itself.
- Offer persistent hardware media/system actions using recovered Field Console consumer-control assignments.
- Offer macOS-specific local macros by using verified carrier keys and an optional local action runner.
- Include a CLI for repeatable scripted remaps and debugging.
- Make the project easy to publish as a small public SwiftPM repo with manual build instructions.

## Non-Goals

- Firmware flashing, bootloader entry, QMK flashing, or firmware backup.
- Full macro recording/playback parity with Field Console.
- RGB, polling rate, wireless pairing, or firmware update management.
- Editing the onboard macro script payload behind the default macro slots.

## User Experience

The app opens as a normal macOS utility window with a sidebar:

- Devices: lists connected Field75 HID interfaces and highlights the selected 64-byte control interface.
- Macro Keys: shows G1-G8 rows with target pickers, modifier toggles for keyboard assignments, and an Apply button.
- Logs: shows readback, plan, write, and echo/status output.

For persistent keyboard mappings, users can choose F13-F24, letters, numbers, arrows, common editing keys, and modifier combinations. For persistent hardware actions, users can choose the recovered Field Console assignments for media, volume, browser, and launch controls. For restoring default behavior, each G key can be mapped back to its corresponding macro slot reference.

For Mac Macro actions, users choose a local action such as running a named Shortcut, opening an application, or opening a URL. The app writes a stable carrier function key to the keyboard and, while the action runner is enabled, intercepts that carrier key on macOS to perform the local action. The UI must make clear that these local macros require the app to be running and may require Accessibility permission.

## Safety Invariants

- The app never sends firmware update, erase, bootloader, or arbitrary HID reports.
- Live writes use only the previously proven Field Console capture sequence and block `0x38` assignment writes.
- Users must explicitly confirm writes from the app.
- The app applies all G-key choices together so later writes do not accidentally revert earlier G-key choices because Field75 readback can be stale.
- Readback is treated as a template and diagnostic signal, not as authoritative active state after a write.

## Success Criteria

- The app builds with `swift build`.
- The GUI launches through `./script/build_and_run.sh`.
- Unit tests verify frame checksums, capture-sequence length, assignment encoding, and G-key overlay behavior.
- The CLI can list devices, print targets, dry-run a remap plan, and apply a remap only with explicit confirmation.
- A user can remap G1-G8 to F13-F24 or restore macro slots from the app.
- A user can select hardware action presets such as Next Track, Play/Pause, Volume Up, and Browser Back that are written directly to the keyboard.
- A user can configure Mac Macros that map the keyboard to carrier keys and are handled by the macOS action runner while the app is running.

## Open Evidence Gaps

- Hardware media/system actions are inferred from Field Console's assignment table and should be manually verified across more actions than the already proven keyboard assignments.
- The live Field75 write path uses G-key assignment indices recovered from capture/readback behavior; the extracted default JSON uses a different logical key list. The app must document that live indices are the trusted mapping for this hardware path.
