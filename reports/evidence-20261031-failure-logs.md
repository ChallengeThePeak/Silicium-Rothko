# K70U Failure Evidence Re-Audit

Date: 2026-10-31 (Asia/Shanghai)
Worker: failure_logs
Shared plan: .planning/2026-10-31-k70u-uefi-lk-evidence
Status: evidence_complete; independent candidate review pending

## Scope And Evidence Boundary

- Read-only audit of prior reports, saved expdb images, and original output
  references in D:/漏洞/UNIXNU/适配K70U.
- No device operation, old build script, deletion, or existing-file overwrite.
- Historical report text is secondary evidence until corroborated with the
  original binary's current header-declared section.
- A watchdog snapshot PC inside a global exception handler does not locate the
  original fault, and absence of a fresh dump does not demonstrate success.
- Shell/custom-parser observations are not REA Evidence.

## Initial Findings From Historical Reports

| Finding | Evidence Type | Reference | Verification Still Required |
|---------|---------------|-----------|-----------------------------|
| The earliest port used OS1.0.22 Android 14 / factory-20240820 inputs, not the user's newly selected OS3.0.302 Android 16 package | Historical report/source provenance | 00-source-audit.md:47, 48, 55, 56 | Compare current stock contract independently. |
| The historical phone was reported as a 24 GB variant with runtime FB 0xFD91F000, carveout 0x026E0000, 1220x2712 CMD+DSC panel | Historical device-read report | 10-uefi-build.md:45, 47, 49, 50; 11-display-findings.md:10 | Raw capture provenance/current stock applicability. |
| 22/23/24 diagnostic reports claim same-EL data abort, bad address, ELR, then module/RVA | Historical recorded output excerpts | 12-fault-beacon-2026-10-25.md:204, 264, 306 | Verify each expdb binary's valid section, image identity, and encoded beacon version. |
| The quoted fault was DxeCore!CoreFreePoolI +0x28 at instruction `ldr w26,[x20,#-0x18]!` and implies Buffer=9 when FAR is -15 | Historical report plus arithmetic | 12-fault-beacon-2026-10-25.md:319, 326, 333 | Validate against preserved PE/map and original dump. |
| A pointer value 9 is not by itself proof of an EFI_OUT_OF_RESOURCES truncation | Inference limitation | Historical proposed cause at 12-fault-beacon-2026-10-25.md:380-384 | Requires a caller/dataflow chain; none shown there. |
| Reports say 26 and 27 reused the old 24 dump | Historical negative evidence | 12-fault-beacon-2026-10-25.md:442-445, 479-482 | Parse actual current sections and boot history instead of all-image strings. |
| “No fresh dump” was treated as proof pool hardening worked / HALT disappeared | Unsupported historical inference | 12-fault-beacon-2026-10-25.md:445, 604-605 | No new dump does not establish either execution path. |

## Work Log

- Read installed planning-with-files skill completely.
- Read project AGENTS.md and CLAUDE.md.
- Resolved explicitly pinned shared plan; read its three files.
- `git diff --stat` scoped to reports and work/expdb returned no tracked changes.
- Shallow inventory found saved 128 MiB expdb captures from 00:52 through 16:27
  on 2026-10-25; two zero-size captures are unusable.
- Read 00-source-audit.md, 10-uefi-build.md, 11-display-findings.md, and
  12-fault-beacon-2026-10-25.md completely.
- Read the saved expdb/session scripts. They analyze whole-partition `strings`
  output or split at text landmarks; none validates a partition/header current
  data window. Do not run them as authority for boot recency.
- The 14:19 binary is zero-filled at offset 0 through at least 0x1FF, while its
  full-image strings end with `PL_LOG_STORE:save last preload sram log offset
  0xF98E0, size 0x7F7C`. This is evidence of retained log-store structures,
  not yet a decoded chronological session.
- Located only bounded, relevant parent analysis scripts by filename, including
  expdb-structure.py, expdb-b11-logstore.py, read-yunluo-expdb-log.py, and
  expdb-last-snapshot.py; will inspect them before any reuse.
- Parent conveyed the latest user clarification that Android 14/16 inputs are
  interchangeable for this investigation. Version identity is retained solely
  as provenance; a version difference is not asserted as a failure cause.
- Generated `work/evidence-20261031/logs/raw-discovery-141928-162718.json`
  with a read-only mmap scanner. This scans only those two explicitly selected
  binary files and labels every textual hit as unclassified.
- SHA-256 14:19 capture:
  bb65751a60e9b4e43312d6b2cec659c3d0342289058712a29c40e0af0398a663.
- SHA-256 16:27 capture:
  4f09ec8abb89ade41227272b636e1837e4498418d36e5e9e1f7e87d77a6184be.
- The entire 16:27 capture has zero `kernel_sz` and `cpu(0)` strings. It contains
  RGU parse status 2, MODE 0x25, LENGTH 0xFFE0, SWSYSRST 0, NONRST_REG 0 at
  offsets near 0x7FE25xx and 0x7FEB9xx, alongside many retained earlier boots.
  Until the current window is selected, these observations cannot be assigned
  to 31 (or prove 30 executed) solely by the capture filename.
- Neither selected capture contains YUNLUOG1, the sram ABCD1234 binary signature,
  or the probed PLLK/DBGB/BLOG signatures. The yunluo XNU header reader does not
  establish the K70U MTK log-store current window.

## Outstanding Work

- Review root's independent corrected candidate when its source path is ready.
- Hardware UEFI/display success is outside this offline evidence audit.

## Original Binary Re-Checks

- 23 capture (expdb-full-20261025-142426.bin) contains AEE magic 0xAEE0DEAD
  at byte 0, version 18, table size 0x2030, block size 0x1000,
  AEE partition span 0x7D00000, exp_type=1 and wdt_status=6.
  Its records are 64 bytes, with names at record+0x20.
- The 23 table explicitly declares SYS_CUR_PLLK and TFA_DEBUG_BUF.gz. These
  can be extracted by valid records instead of searching residue.
- In 22, 24, 26-era and 30-era captures, the populated data is confined to the
  last 2 MiB (plus a small footer in 22), with no AEE header at byte 0.
  They contain historical ring logs but lack that snapshot authority.
- 24 CPU record at 0x7F98D34 is byte-for-byte identical in captures 14:33,
  15:20 and 15:31: PC 0x43784DB0, LR 0x4478654325007BD4, timestamp 33.323422.
  The matching kernel_sz remains 0x48381 at 0x7F8AA65. This proves reuse
  of the old 24 log in the later captures, not a fresh fault in 26/27.
- Missing-path reads: the guessed name 0003-rothko-memory-hardening.patch
  did not exist; shallow inventory found 0003-rothko-pool-hardening.patch,
  which was read. The historical OnePlus aee source directory was absent
  at the report's path; no expanded filesystem search was performed.
- `decode_aee_sections.py` validated all 56 populated records of the 23 AEE
  header, including bounds and non-overlap, and extracted only selected sections
  to the new `work/evidence-20261031/logs/aee-23-validated/` directory.
- Header-declared TFA_DEBUG_BUF.gz: original partition offset 0x26B9CBB,
  size 4718, SHA-256
  15d46b853bb9004ce2aaddc4f29662e22f68ea2e9ff9a87eb678e4a0cbea5769.
- Its decoded bytes at 0xD4D contain the 23 beacon:
  PC=0x43784D58, LR=0x2543B86BD4FFFFF1, SP=0x4223EAD0,
  PSTATE=0x820003C4 at elapsed time 33.330315 seconds.
- The same live ATF snapshot has RGU MODE=0x7D at decoded 0x983,
  LENGTH=0xF000 at 0x9A9, NONRST_REG=0 at 0xA2C, and Status=IRQ/HW_WDT
  at 0xBF4..0xC3B. This proves the hardware watchdog timed out while the
  CPU was spinning in the exception diagnostic. The bad free is the
  earlier fault; watchdog expiry is the later reset, not proof of its cause.
- Header-declared SYS_CUR_PLLK: partition offset 0x241B079, used=148859,
  SHA-256 e0c45e8ae9b994232b1a4bc61051dbfafab8fe9e47c159eadcc75526e91c091f.
  It records reset recovery RGU status=6, MODE=0x25 and LENGTH=0xFFE0.
  Do not confuse these recovery values with the failing CPU's live values.
- Parsed all 30 present historical numbered boot images (01..31; no 13) using
  the Android v3/v4 header and gzip/ARM64 Image header. The 23 image is
  SHA-256 b6b0352bfcd282cab1a67b9eba5d0c0ed1c97dd791550d6064d86eb1c796a9ab,
  with kernel_size=0x48351, matching the 23 record exactly. All use
  text_offset=0x42000000. 06 and 07 have identical complete hashes and are
  the same bytes despite their different filenames.
- The 31 image kernel_size is 0x48378. No selected saved capture records that
  value; the report offers only its expected behavior, not a device result.

## AEE DTB Cross-Check

- Standard `fdtget` successfully parsed the header-declared SYS_DTB_FILE,
  SHA-256 7232238036143cb22ce428c0d60b1ef45e1d92b762038b801b2f9aa336801f4a.
- `/interrupt-controller@c400000` compatible is `arm,gic-v3`; its standard
  `reg` cells are:
  `0 c400000 0 40000 0 c440000 0 200000`.
- Therefore the first register region of this standard GICv3 node is
  distributor 0x0C400000+0x40000, and the second is redistributor
  0x0C440000+0x200000. This contradicts the old reports' interpretation
  of unrelated debug/alias regions as GICD=0x0C000000/GICR=0x0C400000.
- The existing `work/extracted/vendor_boot_dtb0.dtb` has the same standard
  controller reg cells.
- The AEE DTB `/chosen` contains only bootargs, mkp_panic, kaslr-seed and
  phandle. It does not expose the runtime x0 FDT's framebuffer/initrd
  handoff fields, so it must not be presented as a fully fixed-up x0 DTB.
- A combined fdtget command stopped at absent root path `/gic500@c000000`;
  prior successful GIC reg output remains valid, but later properties in
  that same invocation were not executed. They are read separately next.
- Root-level FDT children were enumerated only within this exact DTB. They
  contain `/interrupt-controller@c400000`, `/bus-parity@c000900` and `/soc`,
  not a root `/gic500@c000000`. Standard-node output, not debug aliases,
  remains the controller source of truth.
- Model is MT6989; PSCI method is smc. The chosen bootargs are the static
  vendor console/root=/dev/ram args, supporting the limit that this is not
  the fully runtime-patched entry FDT.
- Current source confirms UEFI stack 0x42200000+0x40000 and DXE heap
  0x42280000+0x01C00000 at MemoryMapLib.c:30,38. The latter ends at
  0x43E80000 and contains the recorded DxeCore/ArmCpuDxe addresses. This
  corroborates configured low-memory residency, not allocator correctness,
  exhaustion cause, or capacity on the user's current hardware.
- A fdtget multi-property command with `#redistributor-regions` lost its
  argument through the native Windows/WSL wrapper and returned the documented
  even-argument error; it produced no memory/timer result. Retry without
  that problematic argument will be bounded to the three known properties.
- Successful separate property read: memory reg is
  `0 40000000 0 40000000` (1 GiB static placeholder), watchdog reg is
  `0 1c00b000 0 100`, and timer clock-frequency is `c65d40` (13 MHz).

## Header-Declared Memory Evidence

The following line references are in the extracted, header-declared
`work/evidence-20261031/logs/aee-23-validated/SYS_CUR_PLLK`, not a strings
scan of unselected ring residue.

| Range | Raw Record | What It Supports |
|-------|------------|------------------|
| mb_kernel: 0x40000000+0x07C80000 | lines 1880,2809 | Low carveout ends at 0x47C80000. |
| mb_dtb: 0x47C80000+0x00400000 | line 2810 | DTB buffer is adjacent and must remain reserved. |
| aee_debug_kinfo: 0x48080000+0x10000 | line 2811 | Do not allocate through AEE metadata. |
| pstore: 0x48090000+0xE0000 | line 2812 | Do not allocate through pstore. |
| BL31: 0x48800000+0x200000 | line 2814 | Preserve EL3 firmware reservation. |
| mb_ramdisk: 0x66F00000+0x04000000 | lines 1896,2820 | Preserve the reserved ramdisk buffer. |
| BL33: 0x50700000+0x12000000 | line 2818 | This reservation is not the low UEFI heap. |
| log_store: 0x63FFBE000+0x40000 | line 2827 | Old log-store DRAM region is high physical memory. |

Configured UEFI FD is 0x42000000+2 MiB, stack is 0x42200000+0x40000,
and DXE heap is 0x42280000+0x01C00000. The whole heap falls within mb_kernel.
The 23 ATF record's SP=0x4223EAD0 and TTBR0_EL1=0x43E7F000 fit the stack
and heap respectively. This is consistency evidence, not proof that the
heap was uncorrupted or that increasing it fixes the bad free.

## Numbered Image And Event Timeline

The complete header/hash catalog is
`work/evidence-20261031/logs/historical-boot-image-identities.json`.
The diagnostic-only images named `diag-rothko-*` are a separate namespace.
The early numbered experiments in 11-display-findings.md mix UEFI and
standalone payload descriptions; do not assign all of them to equally
numbered UEFI images merely by the number.

| UEFI Image | Observed Or Reported Event | Confidence/Limit |
|------------|---------------------------|------------------|
| 01/02 | Built BootShim+2 MiB FV; historical report says logo stayed unchanged | Header/hash verified offline; device outcome is historical report, no PC evidence in this audit. |
| 03..12,14,15 | Many independent build/diagnostic changes | Artifacts cataloged; no uniquely identified device result assigned by this audit. |
| 16..21 | Reported approximately 33-second watchdog resets; handler PC alone used in earlier analysis | Historical report 12:4-8. A handler PC is not the original fault PC. |
| 22 | kernel_sz=0x482FD; PC=0x43784D5C; LR=0x2500FFFFFFFFFFF1; time=33.327586s | Raw ring record 0x7E8DD34 matches image header and v1 encoding. AEE head absent, so historical event correspondence only. |
| 23 | kernel_sz=0x48351; PC=0x43784D58; LR=0x2543B86BD4FFFFF1; time=33.330315s | Valid AEE v18 snapshot and decompressed ATF section; strongest crash evidence. |
| 24 | kernel_sz=0x48381; PC=0x43784DB0; LR=0x4478654325007BD4; time=33.323422s | Raw ring record 0x7F98D34 matches v3 DxeC/EC25/RVA7BD4 encoding. Head absent. |
| 25 | Caller beacon v4 artifact exists, kernel_sz=0x4838F | No fresh v4 caller beacon found in the selected captures. Caller remains unknown. |
| 26 | New hardening artifact kernel_sz=0x483A0; reported earlier reset | 15:20 capture still contains identical 24 event at identical byte offset. It does not establish execution beyond the bad free. |
| 27 | Survival artifact kernel_sz=0x48391; reported about 15-second reset | 15:31 capture also reuses identical 24 event. PMIC explanation is not a proven final cause. |
| 28 | MMIO-bisect artifact kernel_sz=0x48387 | Later report mentions reset; no uniquely identified fresh fault in the selected captures. |
| 29 | Display-align artifact kernel_sz=0x48373 | Artifact verified; no unique fresh crash assigned here. |
| 30 | No-halt artifact kernel_sz=0x48392; reported about 15-second reset | Latest 16:27 capture contains no kernel_sz/CPU records and RGU SW-reset candidate blocks; absent identity/head prevent assigning a specific executed image offline. |
| 31 | WDT-keep artifact kernel_sz=0x48378 | Only expected acceptance conditions in historical report; no subsequent saved capture or hardware success. |

## Conclusions By Evidence Class

### Measured Saved-Artifact Evidence

1. The 23 valid AEE snapshot proves the CPU reached the UEFI DXE exception
   handler and was spinning there when RGU IRQ/HW_WDT expired at ~33.33s.
2. The diagnostic LR encodes same-EL Data Abort (EC=0x25),
   ELR=0x43B86BD4, and FAR low 24 bits=0xFFFFF1.
3. The 22/24 ring events corroborate full FAR low 48 bits and DxeC/RVA7BD4.
   They do not carry an active AEE header.
4. The 24 event bytes persist unchanged into 26/27-era captures.
5. Standard AEE DTB GICv3 reg data contradicts the existing UEFI's GIC bases.

### Source/Static Confirmation

- Historical DxeCore map/disassembly places RVA7BD4 in CoreFreePoolI+0x28,
  `ldr w26,[x20,#-0x18]!`. Combining the diagnostic fault with that
  instruction implies the caller passed Buffer=9. This worker independently
  validated the saved register evidence but did not recover the matching
  historical PE; that precise symbol/instruction mapping still relies on
  the preserved historical report and should be byte-checked by the root
  investigation before being promoted to independent binary confirmation.
- Current pool hardening rejects low/unaligned pointers; this can avoid the
  immediate bad dereference but does not identify or repair its producer.
- Current GIC map bases at MemoryMapLib.c:63-64 are wrong relative to the
  standard `arm,gic-v3` node. Increasing the window does not correct a base.
- The configured 28 MiB heap is consistent with the saved mblock reservation.

### Reasonable Inferences, Not Proven Causes

- The 23 reset followed a real UEFI fault; it was not simply failure to enter
  BootShim/SEC. This does not demonstrate a completed GOP/console/BDS path.
- A pool corruption/status-to-pointer/protocol ownership error can produce
  Buffer=9. No preserved v4 caller or def-use chain singles one out.
- Latest saved RGU blocks suggest a software-watchdog/dual-mode reset.
  They do not prove 31's watchdog timer fired or failed.

### Blocked Or Unknown

- The actual bad-free caller and why its argument became 9.
- Whether later hardening/DSI changes were reached on hardware.
- Fresh 31 heartbeat/entry/GOP/console evidence.
- Complete runtime x0 FDT and framebuffer fixups at UEFI entry.
- Whether the corrected GIC and mapping candidate boots and displays UEFI.

### Next Step

Independently review root's corrected GIC/mapping implementation, check that
all intended bytes enter the fresh artifact, and keep hardware success separate
from this finite offline validation.
