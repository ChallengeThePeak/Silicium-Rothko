# K70U UEFI And Alternate LK Contract Audit

Date: 2026-10-31 Asia/Shanghai
Worker: uefi_contract
Task plan: `.planning/2026-10-31-k70u-uefi-lk-evidence/`

## Scope And Safety

This report owns only its own text and
`work/evidence-20261031/uefi-contract/` outputs. No shared firmware sources,
historical images, device state, or shared planning files are modified.

## Initial Observations

- `src/uefi-rothko` is an overlay with `files`, `patches`, `Platforms`,
  `Resources`, `scripts`, and `Silicon`.
- `src/Mu-Silicium` is the complete older UEFI checkout, including `BootShim`,
  `Build`, `Common`, `Mu_Basecore`, `Platforms`, and `Silicon`.
- The sibling `重新适配k70u基于lk` is the YukinoXNU boot-layer LK project,
  not the supplied stock MTK LK image. Its README identifies the source as
  Yukino-XNU/YukinoXNU at `8fa24dee1989478b1c8282482304809119fec54c`.
- The sibling reports offline LK builds, not a complete MT6989 XNU port:
  SMP, UART, PMIF, UFS and native XNU remain gated.

## Historical Claims Requiring Source/Artifact Cross-Check

- Sibling `findings.md` records BL31 WDT PC `0x4000b628` mapping to its
  `lk_memu_run` `wfe; b .` loop, EL1h with MMU/D-cache off.
- Later sibling `progress.md` records PCs in `lk_platform_idle` and
  `lk_memu_step`, still ending in HWT after keepalive, RGU MODE `0x7d`.
- Those are historical report observations. This audit has not independently
  parsed the raw expdb and must not convert those statements into a new
  hardware test.
- The old K70U reports record a DxeCore pool fault and later watchdog resets.
  Their precise image and source correspondence will be inspected below.

## Evidence Policy

Use raw log observations, source/compiled-byte confirmation, inference, and
unknown as distinct evidence levels. Successful compilation does not prove
device startup, display refresh, or watchdog ownership.

## Open Questions

1. Which entry/relocation state does the built UEFI require?
2. Does its MMU table map MT6989 GIC/WDT/display resources correctly?
3. Does retained source actually match the final old image?
4. Which watchdog is firing, and is the old kick usable from EL1?
5. Can the alternate LK normalize a UEFI handoff without inheriting its
   unsupported device services?

## Source-Confirmed Early Findings

### GIC Configuration Contradiction

- Old overlay `Silicon/MediaTek/MT6989Pkg/MT6989Pkg.dsc.inc` sets
  `PcdGicDistributorBase = 0x0c000000` and
  `PcdGicRedistributorsBase = 0x0c400000`.
- Its `Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c` maps
  those same addresses and expands its assumed redistributor window to
  16 MiB. The comment treats the `mediatek,gic500` vendor node as the standard
  distributor and combines both `arm,gic-v3` reg ranges as redistributors.
- This conflicts with the sibling's structured-resource implementation/report,
  which uses standard `arm,gic-v3` reg[0] `0x0c400000 + 0x40000` for the
  distributor and reg[1] `0x0c440000 + 0x200000` for redistributors.
- The original vendor DT table and actual GIC driver accesses still need
  the independent cross-check documented below. Expanding the MMIO mapping
  does not prove correctness: a mapped register address may be the wrong
  block or an unsafe MMIO hole.

#### Original DTB Confirmation

The read-only command

```text
wsl.exe -d Ubuntu2404 -- fdtget -tx \
  /mnt/d/漏洞/UNIXNU/适配K70U/work/extracted/vendor_boot_dtb0.dtb \
  /interrupt-controller@c400000 reg
```

returned:

```text
0 c400000 0 40000 0 c440000 0 200000
```

The raw DTB SHA-256 is
`824d63e438703659367e9598dca6b05abdf95a74c1cb778bd298ded9075e34b2`.
Its pre-existing structured dump
`work/extracted/vendor_boot_dtb0.txt:1383-1391` identifies `arm,gic-v3` and
those two reg tuples. The vendor `/soc/gic500@c000000` at lines 5893-5895 is a
different `mediatek,gic500` node and does not replace the standard GICD binding.

The old report `reports/12-fault-beacon-2026-10-25.md:14-33` therefore closed
the GIC hypothesis using an incorrect register classification. This does not
prove the GIC caused every historical reset, but the configuration defect
itself is now independently confirmed.

#### Driver Dataflow

`Mu_Basecore/ArmPkg/Drivers/ArmGicDxe/GicV3/ArmGicV3Dxe.c`:

- Lines 778 and 787 consume the old distributor and redistributor PCDs.
- Lines 48-102 find the current CPU redistributor by reading `GICR_TYPER`
  at each candidate and advancing 0x20000 or 0x40000 until `Last`.
- Line 87 performs the first `MmioRead64` at
  `GicCpuRedistributorBase + ARM_GICR_TYPER`. Under the old PCD this is a
  distributor address, not the current CPU's redistributor.
- PPI enable/disable operations later use the computed redistributor plus
  the SGI/PPI frame offset. Even a coincidental affinity match cannot make the
  old base a valid redistributor.

The corrected PCDs must be `D=0x0c400000` and `R=0x0c440000`, with mappings
bounded by the standard reg tuple sizes. A new guard should bound the
redistributor walk rather than map unrelated 16 MiB of MMIO.

#### Generated Build Correspondence

The old ext4 build's actual generated file
`/home/ubuntu/rothko/Mu-Silicium/Build/rothkoPkg/DEBUG_CLANGPDB/AARCH64/ArmPkg/Drivers/ArmGicDxe/ArmGicDxe/DEBUG/AutoGen.h`
still sets distributor `0x0c000000` at line 81 and redistributor `0x0c400000`
at line 89. This is not merely a stale overlay comment: the reused old
build consumed those wrong values. Matching the exact archived image's
module bytes remains a separate artifact-verification obligation.

### Watchdog Keepalive Is Late And Timer-Dependent

- `PlatformSecLib/PlatformSec.c` implements `DisableWatchDogTimer()` as a
  no-op, relying on a comment that LK already disabled the WDT.
- `RothkoDisplayDxe.c` defers WDT MODE/restart accesses and timer registration
  to its driver entry. The 31 candidate's `mWdtKickEvent` is created at
  `TPL_CALLBACK` with a 1-second periodic timer.
- APRIORI loads `ArmGicDxe` and `TimerDxe` before the display driver. A wrong
  GIC driver configuration or a prior hang can therefore prevent the WDT
  timer from ever being created or firing.
- The display refresh callback also runs at `TPL_CALLBACK`; BLT work raises
  to `TPL_NOTIFY`. Long/synchronous work at those levels can delay a WDT
  callback at `TPL_CALLBACK`. Exact polling limits remain under inspection.
- Consequently, compiled keepalive code is not evidence of actual keepalive.
  A bounded early watchdog readback and a minimal high-priority callback are
  more useful than a timer installed inside the complex display driver.

### Build/Packaging Provenance

- The retained builder's actual ext4 source root is
  `/home/ubuntu/rothko/Mu-Silicium`. Windows `src/Mu-Silicium` is not by itself
  proof of the source used by the last old candidate.
- `build-uefi-rothko.sh` copies the overlay into the ext4 tree and applies
  `0001-mtk-sec-entry.patch`, `0002-rothko-fault-beacon.patch`, and
  `0003-rothko-pool-hardening.patch`. It builds into a reused output path.
  It must not be run against that existing tree for the new candidate.
- The packer explicitly uses the separate
  `/mnt/d/漏洞/UNIXNU/src/uefi-sheng/BootShim/BootShim.S`, not the local
  `src/Mu-Silicium/BootShim/BootShim.S`; byte correspondence needs verification.
- The actual ext4 SEC entry includes the saved x0 HOB and CCIDX-aware
  set/way cache sweep. It selects SPSel=1, configures EL1 or EL2 features,
  sets an explicit stack at `0x42200000 + 0x40000`, clears it, and calls C.
  It does not depend on the incoming SP being usable.
- Building for `-march=armv8.2-a+crypto+rcpc` is an ISA subset supported by
  Cortex-X4/A720; the mere absence of `-march=armv9` is not a proven cause.
- The packer's selected shim preserves x0, copies the appended FD, cleans
  the copied instructions to PoC, invalidates I-cache and branches to FD.
  Its ARM64 header image_size includes shim+FD, unlike the unselected older
  local shim that reports only FD_SIZE.

## Input Hashes Recorded During This Audit

| Input | SHA-256 |
|-------|---------|
| `work/bootimg-31/shim.bin` | `8812247aa3fec06ddef9bed9d9df16f230e431e9cf3e88379283c36fbe126c15` |
| `src/uefi-rothko/Silicon/MediaTek/MT6989Pkg/MT6989Pkg.dsc.inc` | `6a3a6b73f3ed30d53d9b32805f05070529db35c51604fb3b74df4a8c30ecd4c6` |
| parent `src/uefi-sheng/BootShim/BootShim.S` | `e3c053fe31bda28780c048b7144cdd407576234bd344bcc2f405f6a985aeb552` |

## Physical Timer Contract

Read-only `fdtget -tx vendor_boot_dtb0.dtb /timer interrupts` returned:

```text
1 d 4 0  1 e 4 0  1 b 4 0  1 a 4 0
```

The interrupt type is PPI (1), with PPI offsets 13, 14, 11 and 10 and
level-high flags (4). Thus secure physical INTID is 29, non-secure physical
INTID is 30, virtual is 27 and hypervisor is 26.

`Mu_Basecore/ArmPkg/ArmPkg.dec:273-276` declares those same defaults:
`PcdArmArchTimerSecIntrNum=29`, `PcdArmArchTimerIntrNum=30`,
`PcdArmArchTimerHypIntrNum=26`, `PcdArmArchTimerVirtIntrNum=27`.
The selected `ArmGenericTimerPhyCounterLib` uses physical timer registers.
`TimerDxe/TimerDxe.c:391-421` registers the corresponding interrupt handlers.

Therefore a physical timer/PPI-number mismatch is not established here.
Correcting GIC distribution/PPI access is necessary before a periodic timer
callback can be considered viable. This remains static contract verification,
not observed timer execution on the phone.

The old ext4 TimerDxe generated `AutoGen.h` also confirms secure 29 at line
89, physical 30 at line 97, virtual 27 at line 105 and hypervisor 26 at line
113. Those generated defaults did not diverge from the source contract.

## Display Contract And Concrete Defects

### Bounds And Mapping

`RothkoDisplayDxe.c:329-383` (`CollectScanout`) checks only the start address
against the framebuffer carve-out, not the entire `PitchBytes * PANEL_HEIGHT`
extent. The later mirror at lines 625-648 can therefore leave the carve-out
despite accepting the candidate scanout. This is a concrete bounds defect,
not a proven cause of the historical FreePool(9) fault.

`ReadDeviceTree` at lines 897-900 accepts any page-aligned base below 4 GiB
with a minimum size. It does not check `base + size <= 4 GiB`, window overflow,
or containment in the actual sparse MMU map. The memory map maps only the
fixed historical `0xfd91f000 + 0x026e0000`. A different accepted live base
is not automatically mapped before the driver probes or writes it.

`InstallGop` at line 941 computes the full pitched framebuffer size without
checking it fits `mFbSize`. The initialization fill at lines 1325-1334 uses
that same pitch. Both need full extent validation before any write.

### Pixel Layout

`CollectScanout` only checks the CFMT nibble for two 32-bpp formats
(lines 358-361). It does not reject cropping, compression, a DIM-color layer,
channel/byte swaps, extended-layer state or incompatible source addressing.
The driver declares GOP `PixelRedGreenBlueReserved8BitPerColor` unconditionally
at line 921, and mirrored layers need not have the same format. That can
produce incorrect colors even if all memory accesses remain in range.

The conservative candidate should either decode a confirmed linear format
and require all adopted layers to match, or refuse unsupported states.
The existing `QueryMode` uses `EFI_STATUS` and `AllocateCopyPool` normally;
this audit found no direct basis to blame its return type for `FreePool(9)`.

### Mutex Selection

`ProbeMutex` at lines 525-529 accepts DSI0's bit 15 or overlay bits 0..3
from *any* sampled bank. Those bit positions identify different modules in
different MT6989 mutex domains. The DSI0 condition should apply only to
the DISPSYS1 bank `0x14201000`, and the overlay condition should apply to the
validated OVLSYS bank, not an unrelated bank.

The standardized `mediatek,mt6989-disp-mutex` node has four reg tuples:
`0x14001000`, `0x14201000`, `0x14401000`, `0x14601000` (each 0x1000).
The old additional `0x14020000` bank is not in that node's resource list.
The static DTB also has a separate `/soc/disp1-mutex0@14020000` template
and `/smi-larb32@14020000` at the same address. Thus blindly adding a map
for the auxiliary address is weaker than removing it from the first
candidate's standard mutex probe set.

The old memory map omits `0x14020000`, while `mMutexBanks` probes it
unconditionally. Reaching `ProbeMutex` under that MMU map has an unmapped
MMIO-read hazard. It does not prove the old image always reached this code.

### Submission And Completion

`PushFrame` at lines 577-598 writes only `DSI_START = 0 -> 1`. It does not
populate the MT6989 DCS `write_memory_start` command or observe a fresh
FRAME_DONE. On BUSY it returns without submitting, but the caller at line
665 still clears `mDirty`, losing that update.

The sibling's `platform/mediatek/MT6989/display.c` has a more constrained
sequence: re-capture the scanout, wait for idle, clear the W0C completion
bits, require clear readback, write CMDQ0 `0x002c3909`, set the queue to
one command with its selector, arm the specific display/OVL mutex pair,
toggle START, then require a *new* FRAME_DONE under a bounded timeout.
That is a source-backed proposal for MT6989, not a demonstrated Xiaomi
display recipe. The sibling's own record says visible output remains
unconfirmed. It must not be described as a guaranteed working replacement.

### OVL Generation Limit

The captured static DTB identifies the six examined units as
`mediatek,mt6989-disp-ovl` and `*-ovl*-2l`. It does not identify them as
OVL_EXDMA. The old driver's four-layer loops exceed the simple 2-layer
model; any extended/compressed state must be rejected or explicitly decoded.
The OS3 stock LK's actual teardown and active layer programming are still
being examined by the stock_lk worker.

## Oplus MT6989 Source Corroboration

These references are the locally available same-SoC Oplus implementation.
They establish register/format semantics, not Xiaomi's exact LK control flow.
Base directory:
`src/OnePlusOSS-mt6989/kernel/kernel_device_modules-6.1/drivers/gpu/drm/mediatek/mediatek_v2/`.

### Format And Address Interpretation

`mtk_disp_ovl.c:1594-1661` (`ovl_fmt_convert`) establishes, without
premultiplied/manual-format mode:

| CFMT | BTSW | DRM layout | UEFI consequence |
|------|------|------------|------------------|
| 2 | 0 | ARGB/XRGB8888, little-endian B,G,R,A | PixelBlueGreenRedReserved8BitPerColor |
| 2 | 1 | ABGR/XBGR8888, little-endian R,G,B,A | PixelRedGreenBlueReserved8BitPerColor |
| 3 | 0 | RGBA/RGBX8888 | Requires exact PixelBitMask or rejection |
| 3 | 1 | BGRA/BGRX8888 | Requires exact PixelBitMask or rejection |

`CLRFMT_MAN` bit 23 and `RGB_SWAP` bit 25 change the interpretation further;
the simple candidate should reject them. Compression, DIM bit 28 and
extended layer/cropping also need an explicit rejection.

`mt6989_ovl_driver_data` at `mtk_disp_ovl.c:5656-5688` confirms normal address
base `DISP_REG_OVL_ADDR_BASE` (0xf40), 34-bit address support, AFBC compression
support and extended-layer address stride 0x10. The regular layer address
macro at line 281 has 0x20 stride. This confirms the need not to treat extended
or compressed buffers as a normal linear framebuffer.

### DSI Trigger Requirements And Limits

`mtk_dsi.c:5925-6000` configures a trigger in separate PRE_TRIGGER, TRIGGER
and EOF phases:

- PRE_TRIGGER optionally runs a MT6989 PHY reset.
- TRIGGER waits for idle, configures high-speed behavior where needed,
  writes DCS `0x002c3909` at the SoC's CMDQ0 offset, sets queue size 1 and
  selector bit 15, and submits START 0/1/0 through GCE.
- EOF waits for idle and restores high-speed behavior.

The MT6989 driver table at lines 13483-13510 uses CMDQ0 offset 0xd00 and
`require_phy_reset = true`. A minimal firmware inheriting a live LK pipeline
must not silently claim that merely adding DCS/START reproduces that complete
sequence. It should not attempt a guessed PHY reset either; Xiaomi's actual
handoff needs stock-LK evidence before expanding hardware programming.

The CPU helper at `mtk_dsi.c:2580-2583` toggles START 0/1. This supports the
toggle primitive but does not establish that START alone supplies the
required panel command.

### Mutex Domains

`mtk_drm_ddp.c:2720` defines MT6989 DISPSYS1 DSI0 as bit 15; the MT6989 table
at lines 6267-6277 has separate DISPSYS and OVLSYS module arrays. That is
why looking for bit 15 or OVL bits in arbitrary banks is not a sound match.

The independent raw `fdtget` query for
`/soc/disp1-mutex0@14201000 reg` returned:

```text
0 14001000 0 1000  0 14201000 0 1000
0 14401000 0 1000  0 14601000 0 1000
```

## Pre-Existing Changes

A completed read-only `git diff --stat` in Windows `src/Mu-Silicium` reports
12 changed files, 158 insertions and 16 deletions, including the SEC cache
patches, framebuffer changes and modified submodule state. This audit has not
reverted or overwritten any of them.

## Audit Errors And Limits

- A shallow probe for `src/Mu-Silicium/Common/SEC` failed; SEC is actually
  under `Silicon/Silicium/SiliciumPkg/Sec`, identified by the patch paths.
- No nested AGENTS.md or CLAUDE.md was found in the explicitly inspected
  overlay, platform, common, and Rothko device directories.
- Initial guesses for the GIC and timer source filenames were incorrect.
  The bounded file inventory resolved them to
  `ArmGicDxe/GicV3/ArmGicV3Dxe.c` and `TimerDxe/TimerDxe.c`.
- The local OnePlus checkout is sparse: the selected driver directory contains
  only clk, gpu, mailbox and soc. No watchdog implementation is present there,
  so Xiaomi-specific watchdog gating still needs stock binary evidence.
- WSL `rg` is not installed. A bounded `find -maxdepth 3` in the two known
  module output directories located their generated AutoGen.c files; no
  expanded search or environment modification was performed.
- A direct WSL grep call with an alternation expression was reinterpreted
  by the launcher's shell. The query was changed to `bash -lc` and separate
  `grep -e` arguments. No file operation or target execution occurred.

## New Candidate Review Checklist

- Correct standard GICD/R values, bounded redistributor walk and exact maps.
- Physical timer PPI 30; no unsupported IRQ number or EL transition change.
- Watchdog handling separate from display, readback/status observable, short
  TPL_NOTIFY callback and an ExitBootServices stop policy.
- Dynamic framebuffer mapping before use, with full base/size/overflow and
  overlap validation; no uncontrolled static fallback.
- Full scanout extents, pitch and format validation before fill/mirror/BLT.
- Only matching mutex domains and supported linear 2L state are adopted.
- A BUSY/failure must retain dirty state, and a submission must require fresh
  completion before being reported as successful.
- No hidden old fault-recovery/pool-return behavior is confused with a fixed
  root cause. Compilation and device success remain distinct.
