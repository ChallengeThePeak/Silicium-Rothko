# K70U Candidate Contract Review

Date: 2026-10-31 Asia/Shanghai
Reviewer: uefi_contract
Scope: `src/uefi-rothko-evidence-20261031`
Status: first source-review pass complete; final post-edit source/image review
is still required. Root is applying the listed corrections.

## Findings To Resolve Before Build

1. The currently read display source still admits compressed/cropped/extended
   layer state after accepting only a CFMT nibble. Full frame containment has
   been added, but it is not enough to make a compressed buffer linear.
   Exact MT6989 source bit definitions will be supplied below.
2. `StartRefresh` still warns on DSI video mode then pushes anyway. The
   candidate should refuse an unvalidated video-mode state rather than write
   the command-mode trigger primitive.
3. The old arbitrary-bank mutex match and auxiliary `0x14020000` probe remain
   in the snapshot read here. Root has explicitly identified them as pending
   fixes, so they are not represented as forgotten finished changes.
4. CFMT2-only, correct BTSW/GOP interpretation and rejection of MAN/RGB_SWAP/DIM
   are also pending root changes at this snapshot.

## Source-Confirmed Improvements

- The GIC memory map now uses standard distributor `0x0c400000 + 0x40000`
  and redistributor `0x0c440000 + 0x200000`.
- The display scanout now validates its full `PitchBytes * PANEL_HEIGHT`
  extent with `RothkoSpanFits`.
- `InstallGop` validates the full pitched canonical frame before configuring
  BLT and uses the configured 1248-pixel fallback stride instead of 1220.
- BLT rectangle validation now occurs before `FrameBufferBlt`, rather than
  relying on a later cache-maintenance check.
- DTB pointer/header/total-size containment is validated before the FDT
  header is dereferenced or parsed.
- The framebuffer mapping containment check is correctly placed:
  `ReadDeviceTree`, then `LocateMemoryRegionByName("Display Reserved")` and
  `RothkoSpanFits`, then `ProbeScanouts`, GOP installation and fill.
  It is not accidentally placed before reading the live framebuffer.
- That policy accepts only an existing mapped historical display window; it
  does not remap an arbitrary new live framebuffer. The final report must
  call it a bounded compatibility gate, not automatic display adaptation.

## Independent Watchdog Review

- `RothkoWatchdogDxe` is APRIORI immediately after TimerDxe and well before
  RothkoDisplayDxe.
- It requires the Timer Architectural Protocol, performs an initial restart
  write and creates a 100-ms `TPL_NOTIFY` callback.
- It writes only WDT_RESTART `0x1971` at `0x1c00b008`, preserving MODE and
  NONRST/reset-routing state.
- ExitBootServices performs a last restart, clears the active flag and
  cancels the periodic event.
- No immediate TPL/API-order defect was found in the examined watchdog
  source. A driver/timer source review cannot prove that the secure firmware
  accepts these writes or that the callback executes on hardware.
- A fault/IRQ-masked loop still times out, which is intentional diagnostic
  behavior rather than a watchdog disable masking every failure.

## Exact Linear-Scanout Rejection Fields

The source is the same-SoC Oplus
`src/OnePlusOSS-mt6989/kernel/kernel_device_modules-6.1/drivers/gpu/drm/mediatek/mediatek_v2/mtk_disp_ovl.c`.
These are not measurements of Xiaomi's live OVL state.

- Global `OVL_EN` at 0x0c: bit 0 must be enabled.
- `SRC_CON` at 0x2c: the simple 2-layer path accepts only bits 0/1, with
  at least one set. Constant/relay/other-layer bits are refused.
- `DATAPATH_CON` at 0x24: physical FBDC/AFBC enable is bit `(layer + 4)`.
  The compression functions at lines 3118-3124 and 3403-3409 explicitly
  derive `lx_fbdc_en = (compress != 0)` and write that field.
- `DATAPATH_EXT_CON` at 0x324: enabled extended layers in low bits 0..2
  must be refused by the simple physical-layer decoder; their compression
  bits are separate and must not be decoded as ordinary layers.
- `CLRFMT_EXT` at 0x2d0: each physical layer's low two nibble bits,
  `[4*n+1:4*n]`, must be zero for the supported 8-bit-channel layout.
- `L_OFFSET` at `0x3c + 0x20*n`: must be zero.
- `L_CLIP` at `0x4c + 0x20*n`: four 8-bit left/right/top/bottom clipping
  fields must all be zero.
- `L_PITCH_MSB` at `0x40 + 0x20*n`: bit 16 is a second sub-buffer and
  bit 20 is a YUV transform; both are unsupported and must be refused.
- `L_RDMA_CTRL` at `0xc0 + 0x20*n`: RDMA enable bit 0 must be set and
  interlace bit 4 must be clear.
- `L_CON[29:28]` is the source selector: COLOR/DIM (28), UFOD (29), and
  PQ (both) are not ordinary linear memory sources.
- `L_CON` vertical/horizontal flip bits 9/10, extended matrix 11,
  matrix [19:16], 3D/landscape/right-first 20/21/22, manual format 23,
  RGB swap 25, matrix controls 26/27 and source/destination key bits 30/31
  are unsupported by the simple GOP decoder.
- Supported simple `L_CON` fields are CFMT2, optional BTSW24, and alpha
  enable 8 plus low alpha byte; if alpha blending is enabled, alpha must
  be 0xff for the adopted opaque plane.
- ROI and source dimensions must be exactly the full panel frame, not
  accepted by a 12-bit mask that aliases a larger encoded dimension.
- Address, full pitched extent, pitch alignment, mapped carve-out and
  color format must be validated together before any fill or mirror.

## Snapshot Concurrency

Root is applying the known fixes while this review reads the new overlay.
This is a staged review, not an immutable final approval. The final source
and compiled-module hashes need one post-edit re-check before delivery.

During a later local read, the DSI0 and overlay mutex-domain tests were
already narrowed to their specific `0x14201000` and OVLSYS banks. That is an
improvement; the final auxiliary probe set and selected enable mask remain
to be reviewed after root's edit is complete.

## Independent Helper Regression

The reviewer compiled the actual candidate `RothkoDisplayBounds.h` in WSL,
using a small SDK-type shim and a separate 128-bit reference model. The test
files and binary live only in the reviewer's owned
`work/evidence-20261031/uefi-contract/` directory.

The deterministic input set includes zero lengths, 40-byte DTB headers,
page boundaries, both historical memory windows and UINT64/UINTN maxima.
AddressSanitizer and UndefinedBehaviorSanitizer were enabled.

Observed output:

```text
PASS span cases=65536 rectangle cases=262144 UINTN=64 bits
```

No sanitizer diagnostic was observed; the executable exited with status 0.
This verifies the helper arithmetic over the declared cases, not display
hardware or that every call site passes the correct window.

| Reviewed item | SHA-256 |
|---------------|---------|
| Candidate `RothkoDisplayBounds.h` | `d370a69d3fdb65fbaabee64785e33178cb60186574a9399376915dc3072c8beb` |
| `bounds_review.c` | `9bb307c4f34f31c4bc289d8c73ec8927d326fa6ccce92d800375b514cc040f7c` |
| `bounds_review-20261031-a` | `f33655fa72dc00836f65e4b4504ccbdcd21541190dd5a1839b3861fc6dac88ff` |

The first compiler launch was rejected by PowerShell's comma parsing in
`-fsanitize=address,undefined` before any compiler action. Quoting that one
argument resolved the parser error; the output guard confirmed a fresh
binary path before compilation. No output was removed or overwritten.

## First-Pass Snapshot Identity

| Input snapshot | SHA-256 |
|----------------|---------|
| Candidate `RothkoDisplayDxe.c` read in this pass | `24e91e79fe7f0e63354e1597a0434b8ee7d8b920259a0e6c554cc4c5697019f3` |
| Candidate `RothkoWatchdogDxe.c` | `5bdb3ff8dd82be259b8ff400f178681f4844ae9dc53ed145e6cabf70058a329f` |

This snapshot still includes the pending format/compression/clip/auxiliary
bank corrections and a START-only frame primitive. It is not a final
candidate approval. The subsequent review should compare completed source
hashes and verify the compiled modules, then retain the hardware-only
uncertainties in the delivery report.

## Evidence Boundary

- Physical timer PPI 30 matches the raw captured DTB and EDK defaults; see
  `evidence-20261031-uefi-contract.md`.
- Same-SoC Oplus register semantics can guide the primitive, but Oplus's
  GCE PRE_TRIGGER/TRIGGER/EOF sequence is not Xiaomi LK runtime evidence.
- The supplied stock LK's teardown may leave a different CPU/display state;
  final adoption must be cross-checked with the stock_lk worker's decompilation.
- No phone, firmware image, or old source was modified by this reviewer.
