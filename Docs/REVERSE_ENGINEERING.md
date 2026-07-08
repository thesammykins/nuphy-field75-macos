# Reverse engineering notes

These notes summarize the evidence behind Field75 Mapper so future contributors
can extend the tool without repeating the whole Windows/macOS capture process.

The project intentionally does not redistribute NuPhy or Eevision binaries,
firmware images, USBPcap files, or extracted proprietary resources. The notes
below describe the observed protocol and the safety boundaries used while
building the app.

## Device identity

Observed wired USB mode:

| Field | Value |
| --- | --- |
| VID | `0x05ac` |
| PID | `0x024f` |
| Product | `NuPhy Field75` |
| Device revision | `0x0108` |
| Configuration interface | HID report ID `4`, 64-byte reports |

Observed 2.4 GHz receiver mode:

| Field | Value |
| --- | --- |
| VID | `0x05ac` |
| PID | `0x024f` |
| Product | `NuPhy Field75` |
| Device revision | `0x0100` |
| Status | Field Console did not configure this mode in the captured session |

The extracted updater configuration referenced bootloader VID/PID
`0x320f:0x503e`, but Field75 Mapper does not implement firmware update,
bootloader entry, erase, or reset commands.

## Evidence sources

The working protocol model came from:

- Static inspection of the Windows Field Console application.
- Static inspection of an older Field75 Windows firmware updater.
- USBPcap/Wireshark captures from a physical Windows 11 machine.
- macOS HID descriptor inspection.
- Guarded macOS readback probes for block `0x38`.
- Guarded macOS write tests that remapped G1 to F13 and F14, then verified key behavior externally.

High-signal public-facing artifacts from the local research session are:

- `FIELD75_FIRMWARE_FEASIBILITY.md`
- `FIELD75_CONSOLE_PROTOCOL_NOTES.md`
- `FIELD75_WINDOWS_CAPTURE_ANALYSIS.md`
- `FIELD75_WINDOWS_CAPTURE_ANALYSIS_20260708_1.md`
- `FIELD75_CONSOLE_APP_STATIC_ANALYSIS.md`
- `FIELD75_PROTOCOL_DECODE.md`
- `FIELD75_GKEY_REMAP_TEST_GUIDE.md`

Those files were generated during the research session and are not committed
here because they include local paths and references to proprietary extracted
artifacts. This document is the public repo version of the useful conclusions.

## HID transport

Field Console uses HID `SET_REPORT` control transfers against the wired control
interface:

```text
bmRequestType: 0x21
bRequest:      9
wValue:        0x0204
wIndex:        1
wLength:       64
```

The report payload format is:

```text
byte 0      report ID: 0x04
bytes 1-2   little-endian additive checksum over bytes 3-63
byte 3      operation
byte 4      block/page id
bytes 5-6   little-endian block offset
byte 7      reserved/status, observed as 0x00 in host reports
bytes 8-63  56-byte payload chunk
```

Read responses reuse the request checksum rather than recalculating it over the
returned payload. Write echoes validate because the echoed payload matches the
host-generated checksum.

## Observed operations

| Operation | Block | Observed meaning |
| --- | --- | --- |
| `0x01` | `0x00` | Handshake/status query |
| `0x02` | `0x00` | Commit/status/transition candidate |
| `0x03` | `0x22` | Device/status query |
| `0x05` | `0x01` | Metadata/status query candidate |
| `0x05` | `0x1e` | Metadata/profile query candidate |
| `0x07` | `0x38` | Assignment table read request |
| `0x07` | `0x06` | Tail block read request |
| `0x09` | `0x38` | Assignment table write |
| `0x09` | `0x06` | Tail block write |
| `0x15` | `0x1e` | Profile/path or metadata write candidate |
| `0x1b` | `0x38` | Secondary assignment table read candidate |
| `0x1b` | `0x02` | Secondary block read candidate |

Only the `0x07` readback path and the captured `0x09` assignment write path are
implemented. Unknown operations should not be exposed without fresh capture
evidence.

## Persistent G-key write sequence

The captured Field Console apply sequence is:

```text
0x03 / 0x22 / 0x0000
0x01 / 0x00 / 0x0000
0x15 / 0x1e / 0x0000
0x02 / 0x00 / 0x0000
0x03 / 0x22 / 0x0000
0x01 / 0x00 / 0x0000
0x09 / 0x38 / 0x0000
0x09 / 0x38 / 0x0038
0x09 / 0x38 / 0x0070
0x09 / 0x38 / 0x00a8
0x09 / 0x38 / 0x00e0
0x09 / 0x38 / 0x0118
0x09 / 0x38 / 0x0150
0x09 / 0x38 / 0x0188
0x09 / 0x38 / 0x01c0
0x09 / 0x06 / 0x01f8
0x02 / 0x00 / 0x0000
```

Field75 Mapper uses that captured sequence for writes. It does not provide a
generic report sender.

## Assignment encoding

Each assignment entry is three bytes.

| Encoding | Meaning |
| --- | --- |
| `0x20 0x00 <usage>` | Keyboard HID usage |
| `0x20 <modifier> <usage>` | Keyboard HID usage with modifier byte |
| `0xd0 0xa2 <slot>` | NuPhy macro slot reference |
| `0x30 <usage_lo> <usage_hi>` | HID Consumer Control hardware action |

Keyboard modifiers use the same byte shape as an ordinary keyboard report:

| Bit | Modifier |
| --- | --- |
| `0x01` | Left Control |
| `0x02` | Left Shift |
| `0x04` | Left Option |
| `0x08` | Left Command |
| `0x10` | Right Control |
| `0x20` | Right Shift |
| `0x40` | Right Option |
| `0x80` | Right Command |

## G-key assignment offsets

The live G-key offsets are not contiguous in physical order.

| G key | Assignment index | Byte offset | Default |
| --- | ---: | ---: | --- |
| G1 | 97 | `0x0123` | `0xd0a201` |
| G2 | 98 | `0x0126` | `0xd0a202` |
| G3 | 99 | `0x0129` | `0xd0a203` |
| G4 | 100 | `0x012c` | `0xd0a204` |
| G5 | 29 | `0x0057` | `0xd0a205` |
| G6 | 35 | `0x0069` | `0xd0a206` |
| G7 | 47 | `0x008d` | `0xd0a207` |
| G8 | 53 | `0x009f` | `0xd0a208` |

Readback can remain stale after a successful behavioral write. The app therefore
stores desired G-key state locally and overlays all eight G-key assignments into
the write plan.

## Hardware actions

Field Console's native media/system actions use assignment class `0x30` with a
little-endian HID Consumer usage.

| Action | Consumer usage | Assignment |
| --- | ---: | --- |
| Play/Pause | `0x00cd` | `0x30cd00` |
| Stop | `0x00b7` | `0x30b700` |
| Previous Track | `0x00b6` | `0x30b600` |
| Next Track | `0x00b5` | `0x30b500` |
| Volume Up | `0x00e9` | `0x30e900` |
| Volume Down | `0x00ea` | `0x30ea00` |
| Mute | `0x00e2` | `0x30e200` |
| Launch Media Player | `0x0183` | `0x308301` |
| Open Mail | `0x018a` | `0x308a01` |
| Open Calculator | `0x0192` | `0x309201` |
| Open Computer | `0x0194` | `0x309401` |
| Browser Search | `0x0221` | `0x302102` |
| Browser Home | `0x0223` | `0x302302` |
| Browser Back | `0x0224` | `0x302402` |
| Browser Forward | `0x0225` | `0x302502` |
| Browser Stop | `0x0226` | `0x302602` |
| Browser Refresh | `0x0227` | `0x302702` |
| Browser Favorites | `0x022a` | `0x302a02` |

The app can generate these assignments, but contributors should still verify
individual actions on real hardware and operating systems.

macOS does not appear to route every raw launch/browser consumer usage to a
system action. Media and volume usages work, but raw usages such as Open Mail,
Calculator, Computer, Browser Home, and Favorites did not produce useful macOS
behavior in testing.

Field75 Mapper therefore exposes platform-specific hardware actions:

- macOS mode uses consumer-control assignments only where macOS handles them,
  and uses keyboard assignments for browser actions where there is a reliable
  macOS shortcut:
  - Browser Search: `Cmd+L`
  - Browser Back: `Cmd+[`
  - Browser Forward: `Cmd+]`
  - Browser Stop: `Escape`
  - Browser Refresh: `Cmd+R`
- Windows mode writes the raw Field Console consumer usages in the table above.

For app launch behavior on macOS, use Mac Macro mode instead of raw hardware
consumer usages.

## Static leads not implemented

Static analysis found a separate 17-byte `HidD_SetOutputReport` writer in the
Windows app. It appears to send compact command-like payloads with leading bytes
such as:

- `0xff`
- `0x22`
- `0x44`

and subcommand-like bytes around:

- `0xaa`
- `0xab`
- `0xac`
- `0xad`
- `0xae`
- `0xaf`

Payload values were derived from app-side tables and clamped to `0xf7`.

This path is not the captured G-key remap path. It may relate to lighting,
device state sync, or another Eevision/NeoUsb device path. Treat it as a lead,
not a safe command recipe.

## Known gaps

Not decoded yet:

- onboard macro script storage
- RGB and lighting effects
- profile table semantics
- knob settings
- wireless adapter configuration
- Bluetooth configuration
- firmware backup/readback
- bootloader recovery
- QMK matrix/pinout/peripheral mapping

## Recommended contribution path

The safest way to extend the project is to capture one Field Console change at
a time on Windows, then diff the report-ID-4 traffic.

Good captures to collect:

1. Change one lighting effect only.
2. Change lighting brightness only.
3. Change one profile slot only.
4. Create a one-step macro, for example `A`.
5. Create the same macro with a different delay.
6. Change only the knob mode, if Field Console exposes it.

For each capture:

- Start with a fresh Field Console launch capture.
- Change exactly one setting.
- Click the equivalent of "Load to equipment".
- Record the post-write behavior on the keyboard.
- Export USBPcap traffic as PCAPNG plus a TShark TSV/CSV if possible.
- Note the exact UI action and expected result.

Do not test unknown writes on a keyboard that cannot be recovered or replaced.
