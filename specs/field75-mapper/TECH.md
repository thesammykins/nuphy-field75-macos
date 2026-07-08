# Field75 Mapper Technical Spec

## Architecture

Field75 Mapper is a SwiftPM package with three products:

- `Field75Core`: reusable HID discovery, Field Console frame encoding, readback, remap planning, and write application.
- `Field75Mapper`: SwiftUI macOS app.
- `field75ctl`: CLI for device listing, target listing, dry-runs, and explicit remap writes.

The app is package-first rather than Xcode-project-first so the public repo stays small and reproducible.

## Protocol Model

The proven Field Console report format is:

- 64-byte output report.
- Report ID `0x04`.
- Little-endian checksum at bytes 1-2 over bytes 3-63.
- Byte 3: operation.
- Byte 4: block.
- Bytes 5-6: little-endian offset.
- Byte 7: reserved/status.
- Bytes 8-63: 56-byte payload.

Persistent G-key remaps use the proven capture sequence:

1. `0x03/0x22/0x0000`, zero payload.
2. `0x01/0x00/0x0000`, zero payload.
3. `0x15/0x1e/0x0000`, fixed profile payload.
4. `0x02/0x00/0x0000`, zero payload.
5. `0x03/0x22/0x0000`, zero payload.
6. `0x01/0x00/0x0000`, zero payload.
7. Full block `0x38` assignment writes at offsets `0x0000...0x01c0`.
8. Fixed block `0x06` tail write at offset `0x01f8`.
9. `0x02/0x00/0x0000`, zero payload.

No other write path is exposed.

## Assignment Model

Each key assignment is a 3-byte value:

- Keyboard assignment: `0x20`, modifier byte, HID keyboard usage.
- Macro slot reference: `0xd0`, `0xa2`, slot.
- Hardware consumer-control assignment: `0x30`, little-endian HID Consumer usage.

The recovered Field Console hardware action table currently includes:

- Media: Play/Pause, Stop, Previous Track, Next Track.
- Volume: Volume Up, Volume Down, Mute.
- Launch/browser controls: media player, mail, calculator, computer, search, home, back, forward, stop, refresh, favorites.

The app distinguishes platform behavior:

- `.windows` hardware mode writes the raw `0x30` consumer-control assignment.
- `.macOS` hardware mode writes raw consumer-control assignments only for media and volume actions that macOS handles, and uses keyboard assignments for browser actions with reliable macOS shortcuts.
- macOS launch actions such as Open Mail and Calculator are intentionally not exposed as hardware-only macOS targets; use Mac Macro mode for those.

The macOS browser shortcut assignments are:

| Action | Assignment |
| --- | --- |
| Browser Search | `Cmd+L` |
| Browser Back | `Cmd+[` |
| Browser Forward | `Cmd+]` |
| Browser Stop | `Escape` |
| Browser Refresh | `Cmd+R` |

The live G-key offsets are:

| G Key | Assignment Index | Byte Offset | Default |
| --- | ---: | ---: | --- |
| G1 | 97 | `0x0123` | Macro slot 1 |
| G2 | 98 | `0x0126` | Macro slot 2 |
| G3 | 99 | `0x0129` | Macro slot 3 |
| G4 | 100 | `0x012c` | Macro slot 4 |
| G5 | 29 | `0x0057` | Macro slot 5 |
| G6 | 35 | `0x0069` | Macro slot 6 |
| G7 | 47 | `0x008d` | Macro slot 7 |
| G8 | 53 | `0x009f` | Macro slot 8 |

The app keeps desired G-key state in memory and user defaults. It reads block `0x38` only as a base template before overlaying all desired G-key assignments.

Readback response checksum fields can fail the write-report checksum calculation even when the payload is useful. Reconstruction therefore accepts `0x07/0x38` payloads by opcode, block, and offset rather than requiring write-style checksum validity.

## HID Safety Gates

- Discovery filters default to VID `0x05ac`, PID `0x024f`.
- Writes require a selected device whose max input and output reports are at least 64 bytes.
- Core validates every generated frame before sending.
- CLI writes require `--apply --confirm FIELD75_WRITE_BLOCK38`.
- CLI plans overlay all G keys; unspecified keys are restored to their default macro slots.
- GUI writes require an explicit confirmation alert.

## Mac Macro Runner

Local app/Shortcut/URL macros use carrier keys:

- The device is persistently remapped to a carrier F-key, usually the G key's matching F13-F20 usage.
- The app stores the carrier-to-action map locally.
- An optional event tap listens for those carrier keys while the app is running.
- Matching carrier key-down events can be swallowed and translated into local actions: run a named Shortcut, open an application, or open a URL.

This keeps onboard macro editing out of scope until the NuPhy macro script payload is understood, while still making the G keys useful for macOS automation.

## Local Plan vs Device State

The app persists row edits to user defaults immediately, but it treats them as a
local plan until the user presses Apply to Keyboard. `Field75MapperStore` tracks
`hasPendingKeyboardWrite` and only clears it after `applyRemapPlan` succeeds.

The visible Apply to Keyboard button exists in both the toolbar and Macro Keys
page because an icon-only confirmation affordance was too easy to miss.

## Permission Repair

Input Monitoring and Accessibility permissions are bound to the app's path,
bundle identifier, and code signing requirement. Build updates can leave stale
TCC rows that look enabled but no longer apply to the current app.

The app and `script/build_and_run.sh reset-permissions` reset:

- `ListenEvent` for Input Monitoring
- `Accessibility` for the Mac Macro event tap

Both use bundle ID `dev.samanthamyers.Field75Mapper`.

## Validation

- `swift test` validates protocol and planning logic.
- `swift build` validates all products.
- `./script/build_and_run.sh --verify` validates GUI bundle launch.
- Hardware writes are not run during automated validation; they require manual confirmation.
