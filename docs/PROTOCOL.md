# T1 Plus HID protocol

## Device identity

The observed T1 Plus exposes Bluetooth HID with USB vendor/product identity `04e8:7021`. Its HID
descriptor declares Digitizers / Touch Pad (`0x0d:0x05`) with four contact slots. Production device
matching must use the complete identity and descriptor evidence, not the incorrect Bluetooth
Appearance value alone.

## Input report 5

The touch frame payload is 19 bytes. Some host callbacks or stored captures include the report ID as
a leading twentieth byte; the decoder accepts either representation when the callback report ID is
5.

| Bytes | Meaning |
| --- | --- |
| `0...15` | Four contact slots, four bytes each |
| `16...17` | Little-endian scan time |
| `18` bits `0...6` | Reported contact count |
| `18` bit `7` | Primary physical button |

Each contact slot is packed as follows:

| Field | Encoding |
| --- | --- |
| Confidence | byte 0, bit 0 |
| Tip switch | byte 0, bit 1 |
| Contact ID | byte 0, bits 2...4 |
| X | byte 1 plus low nibble of byte 2 as high bits |
| Y | high nibble of byte 2 as low bits plus byte 3 as high bits |

A contact is active only when both confidence and tip-switch bits are set. The decoder preserves all
four slots and the reported contact count so higher layers can diagnose firmware inconsistencies
without allocating a variable-length collection.

## Bluetooth label

The device advertises GAP Appearance `0x03c1` (Keyboard); the assigned touchpad value is `0x03c9`.
That firmware value controls the Bluetooth Settings label and is separate from the correct HID touch
usage. The production application does not patch Bluetooth services or firmware.
