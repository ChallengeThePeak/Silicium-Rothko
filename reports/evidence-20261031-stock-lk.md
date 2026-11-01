# Stock MTK LK Evidence Audit (2026-10-31)

## Scope
- Owner: stock_lk worker.
- Input: the user-selected OS3.0.302.0.WNNCNXM stock `images` directory on I:.
- This is the factory MTK LK, not the alternate boot-layer LK in the sibling
  adaptation directory.
- Original partitions are read-only. No device operation is authorized.
- New analysis artifacts belong only to `work/evidence-20261031/stock-lk/`.

## Initial Observations
- Existing `work/lk_dis.py` and `work/lk_xref*.py` hardcode an OS1.0.22.0
  Downloads path, a 0x200 payload offset and a 0x78000000 load base. These are
  historical assumptions, not verified facts about the newly selected OS3 LK.
- Existing `work/parse_stock.py` also hardcodes OS1 inputs. Its vendor_boot
  parser tests for `ANDROID!`, whereas the standard vendor_boot magic is
  `VNDRBOOT`; it therefore cannot validate the selected vendor_boot as-is.
- The old stock parser reads v3/v4 headers through the v0 field layout and then
  guesses placement. A new format-aware parser is needed for evidence.

## Evidence Rules
- Local hashes and binary decoding are local-command/static observations.
- REA Evidence IDs will be listed only for actual REA output.
- Decompiled control flow is not a device runtime observation.
- Every address claim must retain the source byte offset and verified mapping.

## Status
Inventory and provider inspection in progress. No handoff or RAM claim is yet
accepted solely from historical scripts.

## Selected Input Identities
The independently recorded `stock-inventory.json` contains source paths and
SHA-256 hashes, including:

| Image | SHA-256 |
|-------|---------|
| lk.img | 5d1b9bcf16db54a599c7f4927270aa73600374c74fdb20054305f0ff752de242 |
| tee.img | aec74532c2b7723d0cf7b580a7dd0604c4312feb23cd08aecf4b31982340e0fe |
| preloader_rothko.bin | a690f6d80a22a1f1d1900465dd90652032a09bb93c9ed2f2bad4615511efa003 |
| boot.img | 73be8035d17e7583bc17c93d0fb33df516b73dc5a679eab405611308168539e6 |
| vendor_boot.img | abb02e2dc27cba3107b7734f2365f6f46d23188cd916b65c2007afbf0c718a19 |

## Verified Container Observations
- `lk.img` starts with an MTK mkimg header, header_size=0x200. Its first
  component named `lk` has payload_size=0x134fe0. The load-address field is
  0xffffffff; that field does not itself prove a runtime base.
- The LK package also contains `bl2_ext`, `aee`, `lk_main_dtb`, and `lk_dtbo`
  components, separated by certificate components.
- `tee.img` contains an `atf` payload of 1,011,296 bytes, followed by certificates,
  a `tee` component, and `spmc_dtb`.
- Stock boot is Android header v4, header_size=1584, page_size=4096,
  kernel_size=16,547,799, ramdisk_size=0, signature_size=0.
- Stock vendor_boot is v4, header_size=2128, page_size=4096,
  kernel_addr=1,073,741,824, ramdisk_addr=1,727,004,672,
  tags_addr=dtb_addr=1,204,289,536; the raw FDT occupies 444,690 bytes at
  file offset 54,923,264.
- The stored OS3 kernel begins `02 21 4c 18`, the legacy LZ4 frame magic.
  The first parser did not decode LZ4 and correctly leaves the ARM64 Image
  header as unrecognized, rather than deriving an entry from compressed bytes.

## Entry Decode
Capstone 5.0.7 decodes the first LK payload instructions as `mrs x28, CurrentEL`,
two early calls, writes to CPACR_EL1 and SCTLR_EL1, and builds a TTBR1_EL1 table.
These observations are at source file offset 0x200 onward. 0x78000000 is still
the analysis mapping until original relocated pointers or runtime evidence
independently corroborate it.

## Provider Limits
- Existing REA CLI 6.4.0 is present.
- REA's Windows Ghidra provider reports unconfigured; that Windows provider
  supports native x86/x86-64 PE, not raw ARM64 firmware.
- A complete firmware-inspection CLI capture is retained as
  `work/evidence-20261031/stock-lk/rea-firmware-capture.json`.
- No new analysis engine or global configuration is installed.

## Investigation Errors And Changed Approach
| Observation | Resolution |
|-------------|------------|
| REA `inspect-firmware-regions` reports capability_unavailable: Linux and absolute REA_BINWALK_COMMAND required | Continue format-aware mkimg parsing and Capstone static disassembly; do not install an engine. |
| REA `function` with provider=ida rejects raw lk.img as unsupported binary format | Preserve the complete error capture; do not call this a decompilation. |
| Direct existing IDA plugin `get_metadata` connection to 127.0.0.1:13337 is refused | Do not assume an attached GUI database exists. Check the existing local headless IDA capability, without running firmware. |

## New OS3 String-Xref Seeds
These are seeds, not conclusions. Full ADR/ADRP candidates are retained in
`lk-boot-xrefs.json`. Examples include:
- 0x7800fd88: `kernel_sz=0x%08x`.
- 0x7800fe54: `64 bits kernel`.
- 0x7800fed4: `64 bit kernel can't boot at 0x%08lx`.
- 0x7800ff30: `kernel_load_addr=...`.
- 0x780104a8: `lk finished --> jump to linux kernel`.
- 0x7803f5dc onward: `/watchdog`, `apwdt_en`, `apwdten`.
- 0x78072f14: `wdt_status`, `fiq_step`, `exp_type`.

## Corrected OS3 Link Mapping
The earlier 0x78000000 addresses above are explicitly **relative-offset seeds
under a historical mapping**, not OS3 function addresses. Original raw bytes at
file offset 0xe1200 contain:
- Physical start 0x50700000.
- Corresponding virtual start 0xffff000050700000.
- 64-bit linked string pointers of the form 0xffff0000507b....

The new analysis uses physical base 0x50700000 and linked virtual base
0xffff000050700000. The file mapping for the first LK payload is:

```
original_file_offset = (linked_VA - 0xffff000050700000) + 0x200
```

Absolute callbacks copied from old LK analysis must not be called in the OS3 LK.

## Actual Native Decompilation
- Existing IDA Pro 9.0 IDALIB and ARM64 Hex-Rays produced
  `work/evidence-20261031/stock-lk/ida-lk-first.json`.
- The original LK first payload was copied byte-for-byte into an analyst-created
  ELF carrier. Source/wrapper/payload SHA-256 hashes and the exact offset mapping
  are in `lk-os3-analysis.manifest.json`.
- The private analysis database is saved beside that carrier; no existing GUI
  target or user database was modified.
- Decompiler availability is an actual tool result, not an assumed readiness
  statement. The output is direct IDA Evidence, not REA Evidence.
- ELF loader metadata and the uninitialized tail are analyst-generated. They
  are not original firmware metadata and do not prove hardware behavior.
- The first function discovery merged a panic path into a following function.
  That merged pseudocode is not accepted as a faithful function boundary; the
  next pass will split only the private database at verified assembly entries.
- Optional missing goomba/hexx plugins did not prevent the actual ARM64
  Hex-Rays output. No attempt was made to repair global plugin configuration.
- IDA's default analysis attempted a Lumina DNS lookup that failed. The next
  pass will disable its auto-analysis Lumina flag before running auto-analysis;
  no remote evidence is relied upon.

## Verified Kernel Handoff Instructions
At payload offset 0x104c0 through 0x104e0 (original file 0x106c0 through 0x106e0):
- Invoke payload 0x56a6c.
- Set callback to payload 0x118b4.
- Set the SMC identifier to 0xc2000115.
- Pass kernel physical address and FDT physical address as the next arguments.
- Call payload 0x1a7c0.

Payload 0x1a7c0 disables IRQ, invokes platform teardown at payload 0x3914,
converts the callback VA to PA, performs cache maintenance, and invokes
payload 0x1a55c. That trampoline:
- Moves the SMC identifier into x0, kernel into x1, FDT into x2, zero into x3.
- Installs a physical VBAR_EL1.
- Clears SCTLR_EL1.M, executes ISB and TLBI VMALLE1, then branches to callback.

The callback at payload 0x118b4 is exactly:

```asm
mov x4, #1
smc #0
ret
```

The **ATF SMC handler**, rather than the LK string or trampoline, determines
the final exception level and x0 kernel-entry argument. That handler is still
being traced.

## Correction: The 0x56a6c Call Is Not Display Uninit
Actual decompiler output identifies payload 0x56a6c as
`WritePLLKHardresetLog`, reading/writing the `blackbox` partition and saving
preloader/LK logs. It must not be described as display teardown.
The true platform-quiesce call is payload 0x3914 and its init-hook traversal.

## Watchdog Register Sites
Independent Capstone scans retain `lk-wdt-sites.json` and
`atf-wdt-sites.json`. Original LK instructions at payload offsets:
- 0x3f304: read WDT_MODE at physical 0x1c00b000.
- 0x3f314: write WDT_MODE at physical 0x1c00b000.
- 0x3f320: write WDT_RESTART at physical 0x1c00b008.
- 0x3f338: separate WDT_RESTART write.

The ATF payload also directly accesses this same base. These facts corroborate
the correct MT6989 RGU base and refute treating it as only a DTB string.
The exact MODE bits, ownership of security routing, and whether later code
re-enables the watchdog are being resolved from the surrounding functions.
