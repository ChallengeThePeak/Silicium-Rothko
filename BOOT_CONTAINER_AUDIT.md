# K70U Boot Container Audit

Date: 2026-11-01. Offline analysis only; the phone was disconnected.

## Main Finding

The custom images are not equivalent to a modified stock container. The
original packer kept the first header page and replaced the payload, but
discarded all following AVB metadata and the partition footer. Both the
failed tiny LZ4 reset probe and the failed UEFI image have this difference.
The working stock-derived reset images retain those structures.

This is a confirmed packaging omission, not yet a proven cause of the
failed probes. Hash failure tolerance does not imply malformed metadata
tolerance. Whether the boot footer is consulted depends on the real
top-level VBMeta chain, which has not been captured as a partition image.

## Stock Layout

Input: `C:/Users/24718/Desktop/output/boot.img`, 67,108,864 bytes.
All offsets below are offsets in that file, not RAM addresses.

| Offset | Length | Contents |
| --- | ---: | --- |
| `0x00000000` | `0x1000` | Android v4 header page; header structure is 1584 bytes |
| `0x00001000` | `0xFC7FD7` | Legacy LZ4 kernel; decoded size is `0x2270000` |
| `0x00FC8FD7` | `0x29` | Zero padding to the next page |
| `0x00FC9000` | `0x8C0` | GKI `boot` certificate, SHA256_RSA4096 |
| `0x00FC98C0` | `0x8C0` | GKI `generic_kernel` certificate, SHA256_RSA4096 |
| `0x00FCA180` | `0x2E80` | Padding completing the 16 KiB GKI certificate area |
| `0x00FCD000` | `0x680` | Device AVB VBMeta, SHA256_RSA2048 |
| `0x03FFFFC0` | `0x40` | `AVBf` footer |

The footer declares original image size and VBMeta offset `0xFCD000`,
and VBMeta size `0x680`. The outer hash descriptor covers the boot image
including the 16 KiB GKI certificate area. It also carries Android version,
fingerprint and security-patch properties.

The Android header's `signature_size` field is **zero**, despite the
appended GKI certificates. That field alone does not establish that the
remainder of this particular stock image is empty.

The first two certificates match AOSP's GKI certification layout. They
must not be confused with device-specific verified boot. AOSP documents
GKI certification separately from the OEM AVB signing step:
[generic boot](https://source.android.com/docs/core/architecture/partitions/generic-boot),
[certificate implementation](https://android.googlesource.com/platform/system/tools/mkbootimg/+/3886f4a68b9802bc4e13a75b82c756981dc924e2/gki/certify_bootimg.py).

## Compared Images

The machine-readable results are in
`F:/k70u/tools/boot-entry-audit/boot-container-comparison.json`.

| Image | Appended VBMeta objects | Footer | Relevant evidence |
| --- | ---: | --- | --- |
| Original stock boot | 3 | Present | All three payload hashes match their correct input ranges |
| Working stock entry-reset boot | 3 | Present | Metadata signatures remain intact; payload hashes do not match |
| UEFI `boot-pstore-v4-fix1.img` | 0 | Missing | Previous failed boot |
| Tiny direct-SMC LZ4 probe | 0 | Missing | Previous failed probe |
| Stock `init_boot` | 1, unsigned | Present | Payload hash matches |
| Working KSU `init_boot` backup | 1, unsigned | Present | Original descriptor hash does not match the patched payload |
| Original UEFI FAT `init_boot` | 0 | Missing | Original packing discarded its metadata too |

RSA checks used AOSP avbtool against each metadata object's embedded key.
This checks metadata integrity, not whether a device trusts that key.
`NONE` metadata is unsigned, not a successfully authenticated signature.
The `generic_kernel` digest was checked against the compressed kernel
payload, not against the beginning of `boot.img`.

The first 4096 bytes of the UEFI and tiny-probe boot containers differ from
stock only in the kernel-size field. Thus this is not a missing Android
header, command line, or load-address field. The stock boot has no ramdisk;
the generic ramdisk is in `init_boot`, and the DTB comes from `vendor_boot`.

## Packer Behavior

The original `tools/boot_v4.py:build_v4()` copied only the first 4096
template bytes, appended payloads, and zero-filled the remainder.
Its original verifier required zero trailing data and gzip compression.
That legacy mode remains available, but the new `--preserve-avb-tail`
mode retains the complete template tail at its original offsets and
rejects payload overlap. Verification now supports both gzip and legacy
LZ4, and checks preserved bytes against the source template.

Do not describe the old zero-tail output as preserving the complete stock
envelope. Conversely, copying the old tail back does **not** re-sign a
modified payload or make its stored hashes correct. Tail preservation is
an intentional diagnostic control here, not a production signing process.

## LK Evidence

The recovered AVB path distinguishes verification errors from invalid
metadata. This was also checked against the original LK instructions:

- `0xA4EFC..0xA4F2C`: read the partition's last 64 bytes.
- `0xA5014`: validate and decode the footer.
- `0xA5064`: use offset zero and a 64 KiB read if no valid footer supplied an offset.
- `0xA515C`: verify the resulting VBMeta object.
- `0xA5188..0xA51EC`: verification errors can continue when allowed.
- `0xA528C..0xA52C8`: invalid VBMeta header yields invalid metadata, without that override.

If boot is traversed as a chained VBMeta partition, removing its footer
can send verification to offset zero, where `ANDROID!` is not `AVB0`.
If the top-level VBMeta directly supplies a boot hash descriptor instead,
the same footer need not be read. This distinction remains unresolved for
the actual device, so missing-footer causality is not asserted.

Disassembly: `F:/k70u/tools/boot-entry-audit/lk-avb-footer-assembly.txt`.
The general distinction also appears in
[AOSP libavb's error policy](https://android.googlesource.com/platform/external/avb/+/refs/heads/main/libavb/avb_slot_verify.h).
The VBMeta files in `LK_RECOVERY/.../analysis/batch11/avb_check` are marked
`synthetic: true`; they are not evidence of the phone's real AVB chain.

## Inner Image

| Field | Stock kernel | Current UEFI shim | Tiny LZ4 probe |
| --- | --- | --- | --- |
| `text_offset` | `0` | `0x40400000` | `0` |
| `image_size` | `0x2270000` | `0x2000C0` | `0x1000` |
| `flags` | `0xA` | `0` | `0xA` |
| MZ and PE/COFF | Present | Absent | Absent |

`BootShim/BootShim.S` puts `FD_BASE` in `text_offset`. The former is an
absolute relocation destination; the latter is a load offset according to
the [ARM64 boot ABI](https://www.kernel.org/doc/html/v6.1/arm64/booting.html).
This is a semantic defect and should not be carried into the next image.
It is not proven causal: the corrected tiny probe also failed, and the
audited LK decompression path does not use this field for relocation.

The new K70U wrapper normalizes `text_offset` to the target's offset from
a 2 MiB-aligned base and sets flags `0xA`, without changing the shared
upstream shim compiler. The K70U target therefore gets `text_offset=0`.

Flags zero is a legal ABI encoding, not an invalid header by itself.
PE/COFF is relevant to EFI loading; the audited LK path uses the normal
code entry via SMC. Absence of a Linux EFI stub is therefore not sufficient
evidence of a fault. LK contains both gzip and legacy-LZ4 decoders; the
failed LZ4 probe also rules out gzip as the only explanation.

The compiled UEFI FD itself has a valid `_FVH` header, length 2 MiB and
header checksum sum zero. Its reset branch targets offset `0x800`; that
entry starts with `msr SPSel, #1`. The pstore marker is present in the
actual binary. There is no evidence here of a truncated FD or of these
source fixes being absent from the tested build.

## Offline Controls

Two 64 MiB images were prepared under `F:/k70u/tools/boot-entry-audit`:

1. `boot-stock-entry-reset-no-avb.img`: the working stock reset image with
   only the appended AVB region and footer removed.
2. `boot-entry-probe-lz4-direct-smc-with-stock-avb.img`: the failed tiny
   probe with only the stock appended AVB region and footer restored.

Each preserves its baseline's header and compressed kernel byte-for-byte.
Neither has been flashed. Do not infer a device result from their offline
validation. Future tests should change only `boot_b`, retain working KSU
`init_boot_b`, and keep the known stock restore path available.

The previous stock-derived controls remain the execution baseline:
zero-delay reset intervals were 9.585-11.119 seconds; the 20-second variant
produced one measured interval of 32.205 seconds. Their AVB payload hashes
were stale, so those tests establish that a modified payload can execute,
not that malformed or absent metadata will also be accepted.

## AVB Batch

The subsequently requested four-group batch is in
`F:/k70u/tools/avb-v1`, built by `tools/build_avb_experiments.py`:

- `boot-avb-reset-0s.img`: direct reset, no counter reads.
- `boot-avb-reset-20s.img`: timed reset.
- `boot-avb-pstore-20s.img`: write the pmsg ring, then timed reset.
- `boot-avb-uefi.img` and `init_boot-avb-uefi.img`: complete UEFI/FAT pair.

Every image retains its stock AVB tail. All boot payloads use legacy LZ4.
The reset probes reuse their previous compressed payloads exactly. The
pstore marker is `K70U_AVB_PMSG_ENTRY_V1` at pmsg base `0x480F0000`.
The UEFI FD is reused from the compiled build; BootShim is recompiled
and its Image header normalized. All new outputs remain device-untested.
The batch README contains the write/reboot/restore sequence and warns
that the first three tests must keep the working KSU init_boot.
