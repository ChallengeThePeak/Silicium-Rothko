# Findings And Evidence

## Supplied expdBUEFIBX (2026-11-01)
- Input is C:/Users/Administrator/Pictures/expdBUEFIBX, 640127 bytes,
  SHA-256 64b99def629190411549dc9b6b22af63a7833ad756530ffff2b59b8c163440db.
- It is ASCII text with 15193 lines, zero NUL bytes and zero standard gzip
  headers; it is not a complete 128 MiB raw expdb partition image.
- Initial bounded marker scan finds flash:boot_a at lines 5575 and 14324,
  reboot requests at 5627 and 14376, but no kernel_sz, Ready, decompression,
  ATF PC, panic_header or UEFI markers. This absence is capture coverage, not
  evidence that the new image was not loaded or that LK/preloader is the cause.
- Fvfix source remains clean at 544ac2d6980f0d68cc4159bd04c1f24e94c928b3;
  current evidence history is d5c2ba31abd9c7343b03a566d44a00f3494e00de.
- Analyze only this supplied file. No new adb read or phone action is implied.
- Preserved input hashes match. Seven text fragments contain an exact 813-line
  duplicate prefix in fragments 5/6 (SHA f4f2b2cd...). First flash-adjacent slice
  is 5628-6444 and second is 14377-15193; both end at log-saving boundaries.
- No fvfix kernel_size=0x49fba or valid UEFI PC/phase anchor is present. This
  cannot prove non-execution, and the prior raw's zero AEE area cannot be
  projected onto a new text-only file. Report: reports/expdBUEFIBX-20261101.md.

## UEFI Binary Trace (2026-11-01, after confirmed LK loading)
- Definite new defect: actual FD 2c7e7c... has both target GUIDs only inside
  APRIORI RAW data, with zero executable FFS for display and watchdog. Full FV
  header/FFS checksum traversal and generated FVMAIN lists agree. Guid.xref
  lists compiled modules and is NOT package-membership evidence.
- DXE.inc line 38's APRIORI-only/duplicate-copy comment is false. BaseTools
  AprioriSection.py lines 95-119 serialize only GUIDs to a FREEFORM/RAW file.
  Dispatcher.c lines 1427-1442 schedules only matching already-discovered FFS.
- Minimal fix in a new snapshot adds both real INF entries to DXE.inc, retaining
  APRIORI order and all driver C code. Baseline 4630ed3d20933ff6569f5f41f41dbe8ecade5ee0;
  fix 544ac2d6980f0d68cc4159bd04c1f24e94c928b3. New source path:
  /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-fv-membership-fixed.
- scripts/audit-rothko-fv.py now rejects the previous exact FD despite its
  APRIORI references; it requires actual active executable FFS and can compare
  packaged PE bytes with explicit current linked .efi files.
- New final boot ef6dacb910a7edd646cb68c45c60b014bef4d84996dd95196216bcd42f2953c5
  unpacks to FD38edb952ea4501f78871ed8454c3d4ce4a8e1c1013dd4f0dd21fa32fdb94ffdc.
  Actual packaged display/watchdog PE counts are 1/1 and bytes match the new
  linked modules; dangling APRIORI references are empty. Kernel size is 0x49fba.
- This is the corrected release, not the previous 0x48552 keepalive test. Its
  static membership fix is proven; new hardware boot remains untested.
- New local AGENTS.md persistently withdraws the old preloader/LK attribution;
  its checkpoint is 59507066c8711833d3e5c27358b9eec5d8251abc.
- Actual new Sec.efi is 65536 B, SHA-256
  43fb51fb59d2787073955c01b8775d8d6c36c4d4f6c757334c17c1967f8d294c.
  Copied analysis inputs and identities are under work/uefi-trace-20261101/inputs.
- IDALIB/Hex-Rays successfully decompiled SecEntry RVA 0x1050, entry RVA 0xa038,
  region lookup RVA 0x3198 and cache helper RVA 0x906c. IDA's recorded input hash
  exactly matches the copied module. This is direct offline IDA evidence, not
  REA Evidence; the REA provider call was unavailable and is preserved separately.
- Important analysis trap: gSecEntryArg0 at RVA 0xa110 is writable entry data
  placed in .text. IDA warns that its read-only .text assumption can fold it to
  the initial zero. Do not infer a DTB=0 defect from uncorrected pseudocode.
- Direct linked entry instructions select SPSel, retain x0 in x20 across the
  stackless cache helper, store it at 0xa110, and set SP before SecEntry. The
  pre-stack platform helper is RET and ArmEnableVFP uses no stack.
- Actual FD reset branch targets RVA 0xa038 and its entry instructions match
  the flat Sec.efi exactly. The C-entry literal is correctly rebased from
  0x1050 to 0x42001050. No demonstrated broken relocation at this boundary.
- Memory-region lookup leaves the output unchanged on an unsuccessful second
  spelling lookup; the existing DXE Heap/Display Reserved first match is not
  cleared by the underscore fallback. Do not invent that as a boot blocker.
- Independent checks so far: fresh LK framebuffer 0xfd91f000/0x26e0000 and
  1220x2712 command-mode geometry match current source; GIC bases and timer PPI
  numbers also match. Late handoff hardware state still needs explicit evidence.

## Fresh Capture Request (2026-11-01 11:06 Asia/Shanghai)
- User says: enter fastboot, flash the new boot, reboot fails, return to
  fastboot, restore stock boot, first stock boot fails, second succeeds.
- User has erased gz and explicitly asks not to divert the investigation to
  NoGZ/stock-boot instability. Isolate the candidate test, not the restore boots.
- adb reports one connected rothko device, VKMZZDEI4H759TRS (2407FRK8EC).
- Capture will use a new directory beside the known adb installation on I:;
  preserve raw expdb rather than relying on a strings-only partition scan.
- Raw capture is now I:/刷机/root/scrcpy-win64-v3.2/k70u-expdb-20261101-1106/expdb.raw.bin,
  134217728 bytes, SHA-256 dc179bf666686de63883b7370fa2346574a6240cff8f1949bcc3333c9015c12d.
  KernelSU expanded all 50157 LF bytes to CRLF despite adb -T; reversing this
  transformation yields exactly the device-side before-hash. The original
  transport is retained. Device disconnected before after-hash; do not claim
  three-way stability. No temporary file or partition was written on device.
- Positive candidate anchor: full line at raw 0x7f531fc reports
  kernel_sz=0x00048552, matching the new image's 296274-byte gzip. The other
  two kernel-size records are stock-sized 0x015141fe.
- Candidate text at 0x7f21400..0x7f55400 includes AVB img_auth_required=0,
  avb_ret=0, all boot headers, successful DT overlay, kernel decompression
  taking 10 ms, and io_task_callback fdt=0xffff000047c80000. This is positive
  LK candidate-loading evidence, not yet proof of BootShim/SEC/DXE execution.
- Independent AEE audit: first 126 MiB is zero, no AEE magic or gzip header
  exists anywhere. TFA_DEBUG_BUF.gz names are kedump progress text only; their
  referenced payload offsets are zero. Do not borrow old AEE registers.

## Active Reassessment (2026-11-01 continuation)
- The user asks to continue the referenced chat, especially the first failed
  candidate boot before restoring stock. Current stock readback cannot identify
  what ran during that earlier attempt.
- The last entry's claim that text ending at Boot dev init proves execution
  stopped before LK is under review, not an accepted root cause. This ledger
  already contains a positive entry-probe PC despite absent final LK jump text.
- Baseline: parent recovery-main at 9001b0d40c4322537455e6dc1401b0430b8a2439;
  scoped tracked diff is empty. The evidence overlay has a pre-existing modified
  scripts/verify-bootimg.py, which must be preserved.
- Plan explicitly resolved to .planning/2026-10-31-k70u-uefi-lk-evidence.
  No host hook binding or lifecycle-hook activation is claimed.
- Supplied expdb.strings is 575643 bytes, SHA-256
  ef6068d5d146bd23cabef1c0196c8023c403da89de721f95dc5f272ca06fff23.
- Direct counterexample: saved normal proc-pl_lk-normal-20261031.txt has
  #T#WDT_INIT=2 at line 689 and RAM_CONSOLE wdt status 0x800 at line 690,
  then Ready to boot linux at line 4216 and stock kernel_sz at line 4282.
  Those two PL values therefore do not establish a preloader failure.
- The previous first-attempt cutoff excludes lines 6363-6364: early_save_pllog
  and save last preload sram log offset 0x3BF38, size 0x7F7C. The fragment
  explicitly ends at a log-saving boundary after Init Boot Device: OK(0),
  not an observed fault. Neighboring fragments repeat the 0x44000/0x7F76
  save record; byte-equivalent prefix checking is next.
- Independent candidate audit found that the confirmed package manifest points
  to a build result with a different FD hash. It also found uncompiled MODE and
  NONRST changes in a newer copied tree. These are under source audit; do not
  call that tree a successfully rebuilt harmless keepalive variant.
- New parser/test results: 10 tests pass. The capture has five text fragments;
  fragments 3 and 4 contain exactly the same 813-line early prefix, SHA-256
  1111fafde83e1bbc18ca048b0b40db274d7ca00f0ad98f8d4f1a4db4b6a8adf5.
  Fragment 4 then continues into LK. Counting these prefixes as distinct boot
  failures or treating their last line as the CPU stop is invalid.
- Captured first flash-adjacent text is lines 5548-6364, including its actual
  early-save boundary. Original bytes and parser JSON are preserved under
  work/evidence-20261101-continuation/expdb-analysis-01/.
- Confirmed and stage-coded image hashes are identical (18eced1a...); the
  compiled watchdog has the 600-callback cutoff. Only removing that cutoff is
  justified here. It is not a proven explanation for early boot failure.
- Reject the unbuilt newer code that clears MODE.EN and overwrites NONRST.
  The next fresh build preserves those registers and all other staged behavior.
- Capacity: D: has about 216 MiB free; Ubuntu2404 VHDX lives at
  C:/WSL/Ubuntu2404/ext4.vhdx, with about 13 GiB host C: free. Keep source,
  build, package intermediates and full manifests on ext4; copy only one final
  64 MiB boot plus compact records to D:. No cleanup or move is needed.
- Real fresh candidate is now published as
  bringup/boot-rothko-uefi-keepalive-20261101-avbf.img, SHA-256
  01261519293e9ef62756565ccbf94f156a7776145c53edd30858e55e6888bfc6.
  FD is 2c7e7c5179a6781b2e7f69fa55ea70c9ee5d18835cd151e9e8d4482a5bdd3c42;
  linked watchdog module is 96d40e5be3c98a559dfc66148d45610fcb5bd534ec967fe68e915a332427ed32.
- GCC ASan/UBSan tests include the actual old/new C source: new driver passes
  7/7, old driver fails only the intended continuation test (599 versus 10001
  RESTART writes). Stage MMIO is mocked; this is not hardware timing evidence.
- New wrapper/audit bind clean source commit 0b5a75c6716108d4458470938c265b186da7a07e,
  current build log, FD, module, identical inherited Shim, host test sources,
  v4/gzip/AVBf container and published copy. See keepalive-release.json.
- The original early failed-boot location remains unknown; the new cutoff fix
  and provenance correction must not be sold as a complete hardware boot fix.

## Requirements
- Investigate repeated failed K70U adaptations in this directory and prior logs.
- Use decompilation of the supplied stock MTK boot-chain images as evidence.
- Inspect the sibling alternate-LK effort without confusing it with MTK LK.
- Primary requested outcome is a usable UEFI candidate, not merely boot-layer LK.
- The user explicitly authorizes multiple subagents for cross-checking.
- Do not claim hardware success without actual device evidence.

## Initial Bounded Inventory
- Current workspace: D:/漏洞/UNIXNU/适配K70U.
- Shallow children: bringup, logs, reports, scripts, src, work, _quarantine,
  .workbuddy. No files were changed by this inventory.
- Parent: D:/漏洞/UNIXNU, containing AGENTS.md, CLAUDE.md, docs, and Git metadata.
- Actual sibling directory: D:/漏洞/UNIXNU/重新适配k70u基于lk.
- Supplied images:
  I:/rothko_images_OS3.0.302.0.WNNCNXM_20260409.0000.00_16.0_cn_3edf1540ec/
  rothko_images_OS3.0.302.0.WNNCNXM_16.0/images.
- Shallow stock inventory includes lk.img (4,321,120 bytes),
  preloader_rothko.bin (907,924 bytes), tee.img (4,849,264 bytes),
  boot.img and vendor_boot.img (each 67,108,864 bytes),
  dtbo.img, gz.img, init_boot.img, and MT6989 scatter TXT/XML.
- Image identities have not yet been hashed or decoded. Filenames alone do not
  establish code behavior or partition compatibility.

## Evidence Ledger
| Claim | Type | Source | Remaining Limit |
|-------|------|--------|-----------------|
| The selected stock directory exists and contains the listed images | Local command observation | Shallow Get-ChildItem output, 2026-10-31 | No device runtime evidence. |
| Prior and sibling attempts are present | Local command observation | Workspace/parent shallow directory lists | Failure cause remains to be determined. |

## REA Boundary
- The skill and relevant native/evidence/recovery references have been read.
- Existing documented REA CLI is preferred; MCP remains disabled.
- Shell or custom-parser output is not labeled REA Evidence.
- A fresh output directory is required for extraction and analysis artifacts.

## Open Questions
1. Which candidates correspond to which recorded failures?
2. At what exception level, CPU state, and address does stock MTK LK enter boot?
3. What Android header, DTB, and memory placements does this firmware expect?
4. Does the old UEFI use a different SoC's SEC, clock, display, or memory map?
5. What can be proven offline, and what still requires a device test?

## Latest expdb five-record split (2026-10-31)

- The pulled strings file work/evidence-20261031/logs/device-expdb-strings-20261031-221732.txt
  is 2,013,799 bytes with SHA-256
  85749ea53b053516132e622411f49750ea1379f2060cb188693af340378b66af.
- Splitting on the five [SEC] Loading SEC config markers yields exactly five
  logical records in this strings pull. The machine-readable result is
  work/evidence-20261031/logs/expdb-recent-five-20261031.json.
- Record 1 has a 64 MiB boot_a fastboot write, home-key text, and stops at
  wait_for_boot_linux with no Ready/header/kernel markers.
- Record 2 reaches Ready to boot linux, loads boot/vendor_boot/init_boot
  headers, reports the stock kernel_sz=0x015141fe, and decompresses the
  kernel. It also has vbmeta_a HASH_MISMATCH followed by
  img_auth_required=0; this is the original-boot control record.
- Record 3 is an AEE/WDT history entry with wdt_status=0x8000,
  panic_header.wdt_status=0x8000, SYS_CUR_PLLK, TFA_DEBUG_BUF.gz, and
  blackbox boot_index=0, dump_count=3; strings alone has no UEFI PC.
- Record 4 has a 64 MiB boot_a write and stops at wait_for_boot_linux,
  with no Ready/header/kernel markers and AEE status wdt_status=0x2.
- Record 5 has a 64 MiB boot_a write, home-key text, stops at
  wait_for_boot_linux, and later shows AEE wdt_status=0x6,
  exp_type=1, blackbox boot_index=3, dump_count=2.
- The five-record result separates the one normal stock-LK handoff from the
  three early LK-stop records and one AEE history record. Missing strings are
  not treated as proof of a UEFI crash; fastboot download text does not prove
  the payload hash.

## Offline root-cause proof and confirmed package (2026-11-01)

- AEE23's validated TFA record encodes PC 0x43784d58, LR
  0x2543b86bd4fffff1, EC 0x25, and FAR low24 0xfffff1.
- The preserved DxeCore map places CoreFreePoolI at RVA 0x7ba0; its pool-head
  instruction is ldr w26, [x20, #-0x18]!. With FAR
  0xfffffffffffffff1, the freed pointer is exactly 9.
- The staged build's DxeCore disassembly now shows the 0x1000 lower-bound and
  8-byte-alignment checks in CoreFreePool before its call to CoreFreePoolI.
  The staged source also contains BmConsole double-free prevention,
  GraphicsConsole LineBuffer nulling, and warm-reset suppression.
- The new confirmed package is
  work/evidence-20261031/boot-rothko-uefi-confirmed-20261101-avbf.img,
  SHA-256
  18eced1a56c33b9b34d35d037cb2f8b97832f6bf704638d1cd28fa9cc7b78a16.
  It is 64 MiB AVBf, v4, gzip 296322 B, and its decompressed FD matches the
  staged FD SHA-256
  d55a4f9d5cb5a85475c810f8b4824ac50a0c723486e667ee867650b30a847948.
- AVB footer verification reports digest_ok=True; staged SEC/GIC/watchdog/
  display objects contain the planned phase immediates.
- This completes the offline proof of the old fault and its source/package fix.
  No claim of a fresh hardware DXE/BDS success is made until this exact image
  is flashed and a same-attempt expdb is captured.

## Baseline And Early Cross-Checks
- Parent Git HEAD observed: 9001b0d40c4322537455e6dc1401b0430b8a2439,
  branch recovery-main. Relevant-directory tracked diff --stat is empty.
- The full parent status command is still being collected; no pre-existing
  changes have been reverted or committed.
- The explicit planning resolver returned this task's exact isolated directory.
- REA CLI is installed and reports rea@6.4.0. Its --help was read with proxy
  variables cleared in that child process only.
- WSL reports Ubuntu2404, Ubuntu2604, and Ubuntu as installed WSL2 distributions;
  Ubuntu2404 is the project build distribution.
- Applicable project instructions, historical handoff, permissions/restrictions,
  recovery, expdb, offline-activation, and fixed6 handoff have been read.
  The user's new request authorizes multiple workers and a new K70U candidate,
  but does not authorize device operations or deletion.

## Early Worker Observations (Not Yet Independent Final Proof)
- stock_lk reports that old lk_dis.py/lk_xref scripts bind OS1.0.22 Android14
  paths and fixed load assumptions. They are not evidence for OS3.0.302 Android16.
- stock_lk reports parse_stock.py confuses vendor_boot and legacy boot fields.
  New parsing must use actual Android v3/v4 and VNDRBOOT layouts.
- failure_logs identifies the old report's DxeCore CoreFreePoolI+0x28 / Buffer=9
  claim, but its attribution to truncated EFI_OUT_OF_RESOURCES lacks dataflow.
  Raw capture validity and precise image association are still being checked.
- uefi_contract identifies sibling YukinoXNU as a different boot-layer LK;
  old records say it reached lk_memu_run yet still suffered a watchdog reset.
  It is not a demonstrated solution to the MTK handoff contract.
- Old report 11's statement that the entire boot chain is complete is broader
  than its cited diagnostic execution/reset observations. Treat it as a claim
  needing revalidation, not an established UEFI success.

## Source-Confirmed Defects To Cross-Check
- Current MemoryMapLib.c maps 0x14001000 but not 0x14020000.
  Current RothkoDisplayDxe.c adds 0x14020000 to mMutexBanks, and ProbeMutex
  unconditionally reads it. With this sparse UEFI map, that access is not
  covered by a declared mapping. This is a concrete source contract mismatch.
- MT6989Pkg.dsc.inc currently declares GICD=0x0c000000,
  GICR=0x0c400000. Independent source audit reports the standard arm,gic-v3
  node declares GICD=0x0c400000 and GICR=0x0c440000; original DTB and LK
  instruction validation remain pending.
- PlatformSecLib/PlatformSec.c's DisableWatchDogTimer is an empty return.
  The only periodic hardware keepalive is installed much later by the display
  driver after ArmGicDxe and TimerDxe, at TPL_CALLBACK. It is not independent
  of interrupt setup or long display work.
- The old report's "GIC excluded" and "no new dump means pool fix succeeded"
  conclusions exceed their cited evidence and cannot be reused as proof.

## Preserved Worktree State
- Parent status contains unrelated modified yunluo planning files and docs,
  plus unrelated untracked docs/scripts. These remain untouched.
- D:/.../适配K70U/src/Mu-Silicium is on main with pre-existing modified
  submodules, display/SEC/PCD files, and untracked rothko packages.
- Existing ext4 build tree: /home/ubuntu/rothko/Mu-Silicium. It has no .git;
  it must be labeled a local source snapshot rather than an upstream commit.
- clang 18.1.3 and aarch64-linux-gnu-gcc are available in Ubuntu2404.
- Ubuntu2404 ext4 has about 897 GiB free; D: has about 15 GiB free.
  Keep new source/build caches on ext4 and only final artifacts on NTFS.

## User Clarification
- User says Android14/16 are compatible and either LK may be used for reverse
  engineering. Do not present the OS version difference as the failure cause.
- Oplus same-SoC source is allowed for register/driver semantics; Xiaomi's
  supplied bootloader remains the authority for Xiaomi-specific behavior.

## Verified GIC And Historical Fault Evidence
- Root independently ran fdtget on the original extracted vendor_boot_dtb0.dtb:
  `/interrupt-controller@c400000/reg` returned
  `0 c400000 0 40000 0 c440000 0 200000`.
  Text dump lines 1383 onward identify `compatible=arm,gic-v3`.
- Therefore the old board PCDs are definitively inconsistent with the standard
  GIC node. This proves a configuration defect, not its exclusive causality
  for every historical reboot.
- failure_logs validated the actual AEE header in 23's 142426.bin:
  magic AEE0DEAD, v18, table size 0x2030, 56 admitted sections with bounds and
  non-overlap checked. Its valid TFA_DEBUG_BUF.gz contains the v2 beacon:
  PC=0x43784d58, LR=0x2543b86bd4fffff1, EC=0x25,
  ELR=0x43b86bd4, FAR low24=0xfffff1.
- The same valid ATF log records live WDT MODE=0x7d, LENGTH=0xf000,
  IRQ/HW_WDT at approximately 33.33 seconds. This is a watchdog timeout after
  the CPU reached the DXE exception handler.
- Later MODE=0x25/status=6 in valid SYS_CUR_PLLK belongs to the reset-next
  stage and must not be substituted for live ATF registers.
- Valid SYS_CUR_PLLK records mb_kernel=0x40000000+0x07c80000,
  mb_dtb=0x47c80000+0x00400000, pstore=0x48090000+0xe0000,
  BL31=0x48800000+0x00200000. The existing 28 MiB heap is contained.
- 26/27 captures repeat the previous 24 beacon bytes with cleared AEE headers:
  these are residual evidence, not proof that new firmware executed.
- Image 31 has no later associated raw capture in the bounded known directory.

## Independent Candidate Work In Progress
- New overlay: src/uefi-rothko-evidence-20261031, baseline local commit 1f6ff76.
- New ext4 source: /home/ubuntu/rothko-evidence-20261031/Mu-Silicium.
  Local baseline commit 9e130c47dc599d9aae07192e258259e2c2eb0364.
- Complete copied source inventory: 44,489 files/links;
  inventory SHA-256 d32c63858fcd704500c314b96cb1d1a0a894efab3f3634a0973c8ff86430a9d8.
  Manifest: work/evidence-20261031/build-preparation.json.
- No old source/build/image was overwritten. Old build products were excluded
  from the new source, not removed from their original paths.
- Implemented in the new overlay: corrected GIC PCDs/maps; AUX mutex mapping;
  separate TPL_NOTIFY hardware-watchdog timer before display; complete
  framebuffer range/rectangle validation; bounded DTB-header access; retain
  pending dirty frames when the inherited DSI is busy.
- Hardware watchdog MODE/reset routing and NONRST registers are not changed by
  the new service. Feeding works only if hardware timer/IRQ dispatch works;
  that remains a hardware-only runtime claim until tested.
- stock_lk now has actual private IDALIB/Hex-Rays output. LK WDT instructions
  access 0x1c00b000 directly; source-interface claims will be cross-checked
  against that output. Its correct OS3 LK mapping is based near 0x50700000;
  no new UEFI code calls fixed addresses inside LK.

## Fresh Build And Regression Results
- The first build (`build-20261031-01`) was intentionally rejected as a final
  candidate because its ext4 source snapshot predated the overlay edits; its
  0-return result is retained only as a diagnostic record.
- The synchronized source was copied into a fresh ext4 tree and committed as
  `10a14f37eb327477deb7b4f9b45b9381743aaef4`; the final build is
  `work/evidence-20261031/build-20261031-03`.
- Build result: return code 0, firmware size 2,097,152 bytes, SHA-256
  `65450d31fd30072e02ceab512d4f1fb1e64a5f66732267ed16d6527051001f44`.
- `edk-report.txt` and `build.log` show both `RothkoWatchdogDxe` and
  `RothkoDisplayDxe` compiled, linked, and packaged. There are zero build
  `error:` matches and one existing `HwResetSystemLib` library-class warning.
- `check-memmap-alignment.py` passes all descriptors, including GICD
  `0x0c400000/0x40000`, GICR `0x0c440000/0x200000`, and watchdog
  `0x1c00b000/0x1000`.
- The FD container is 2 MiB and begins with a valid FV header. The provided
  `list-fv.py` reports zero named files for this FV layout, so module inclusion
  is asserted from the EDK build report rather than that parser.
- No device write, flash, boot, or reset was performed. Hardware execution,
  watchdog IRQ delivery, panel timing, and Android handoff remain unverified.

## Device expdb LK Handoff Check (2026-10-31)
- Read-only adb/root inspection found device `VKMZZDEI4H759TRS`, expdb size
  128 MiB, and current Android properties `bootreason=reboot`, `bootmode=normal`,
  `sys.boot_completed=1`.
- The last 8 MiB was captured as
  `work/evidence-20261031/logs/device-expdb-tail8m-20261031.bin`.
- Stock LK strings prove the expected markers exist: `Notify boot linux`,
  `booting linux @`, `kernel_load_addr`, `Ready to boot linux`, `64 bits kernel`,
  and `lk finished --> jump to linux kernel`.
- The newest LK sequence in expdb stops at
  `starting app mt_boot` -> `wait_for_boot_linux:1009: Wait for boot linux event...`,
  followed by CCCI modem loading. None of the Linux handoff markers appear in
  the 8 MiB tail. This is the observed LK-side stop point; it is before UEFI/
  BootShim/Linux entry evidence.
- `sec_lk_vb_init() takes 0 ms` and image auth lines pass in the same sequence;
  no explicit vbmeta verification failure is present. Because Android is
  currently booted and expdb contains repeated historical sequences, the tail
  is a boot-history record rather than a guaranteed single current boot.
- User clarification: this expdb was captured after flashing the candidate,
  attempting two boots, observing both fail, and restoring the original system
  before extraction. Therefore the absence of `boot_linux_fdt`, `kernel_sz`,
  `decompress kernel image`, `booting linux @`, and final jump markers is
  evidence against the candidate reaching LK kernel handoff. The earlier caveat
  that the candidate may never have been selected is withdrawn for this capture.
- The next fault domain is earlier than UEFI/GIC/display/watchdog: verify the
  active slot/partition readback, boot image acceptance, AVB/vbmeta policy, and
  LK pre-handoff event path before changing more UEFI code.
- A fresh full 128 MiB read-only expdb capture was taken after the user's two
  failed candidate boots and system restore. It contains two newest
  `wait_for_boot_linux` sequences and still zero `boot_linux_fdt`, `kernel_sz`,
  `decompress kernel image`, `booting linux @`, or final-jump markers. Capture
  SHA-256: `e374ed83b0e7e6b9d3f992fefcd57673769f34554352b62126814a8a05241ace`.

## yunluo vs K70U LK Handoff Comparison
- Yunluo's retained successful evidence contains `boot_linux_fdt:547:
  kernel_sz=...` and `boot_linux_fdt:749: decompress kernel image...`; its
  Mu-only boot image is documented to reach UEFI Shell.
- The K70U stock LK decompilation in `stock-lk/ida-lk-first.json` shows the
  exact chain: kernel size -> 64-bit/DTB checks -> `mb_kernel` address equality
  -> gzip decompression -> initrd/DTB update -> `booting linux @` -> final jump.
- The current K70U expdb tail stops at `wait_for_boot_linux` and has none of the
  handoff markers. The user confirms this tail follows two failed boots with the
  candidate flashed, so it is direct evidence that those attempts did not reach
  LK's kernel handoff.
- Static candidate contract is self-consistent: LK `mb_kernel` starts at
  `0x40000000`, BootShim text offset is `0x42000000`, and the candidate passes
  the gzip/BootShim/FD-size verifier. The remaining hard proof requires one
  authorized temporary candidate boot and a fresh expdb capture containing the
  four `boot_linux_fdt`/jump markers.


## 2026-10-31 fastboot 分支重比对
- 正常 `/proc/pl_lk` 明确共享 `starting app fastboot`、`wait_for_enter_fastboot`、`starting app mt_boot`、`wait_for_boot_linux` 这些前缀；随后正常样本才打印 `Ready to boot linux...` 并加载 boot/vendor_boot/init_boot header。
- 两段失败 expdb 都采到 `home key is pressed`、`boot_reason=1`，并打印 `notify_enter_fastboot`；其后进入 `mt_boot` 等待，但没有 `Ready to boot linux...` 或 kernel handoff 字符串。
- 修正：`wait_for_boot_linux` 不是候选没加载的充分证据；现有记录最多证明失败时 LK 未记录 boot_linux event / 未进入 boot_linux_fdt。无 header 拒绝或 vbmeta 失败的直接证据。若用户未按 home 键，键状态来源仍未知。


## Third-party handoff-stage boot package review (2026-10-31)
- handoff-stage docs provide detailed expdb offsets, repeated raw lines, panic stack, and later `boot_linux_fdt:850`; coherent, non-generic evidence, but raw `blackbox_r8`/`expdb_r8` is not included. Treat LK handoff claim as credible secondary evidence, not independently verified. `lk finished --> jump` does not alone prove BootShim/UEFI execution.
- Their proven recipe is v0 + 0x40000000-aligned kernel address + gzip shim/FD, ramdisk FAT payload, appended DTB and AVBf. K70U current candidate is v4 + zero ramdisk and normal K70U `/proc/pl_lk` shows v4 boot/vendor_boot/init_boot headers loaded then decompression. Borrow packaging discipline and gzip/relocation separation; don't port v0/ramdisk/DTB behavior without need.
- K70U failed expdb is earlier at fastboot event branch, so it doesn't answer candidate header/AVB acceptance. Their `algorithm=0` AVB metadata is not enough to prescribe same footer policy. See `reports/handoff-stage-boot-packaging-review-20261031.md`.


## AVB footer packaging result (2026-10-31)
- Third-party source `Resources/Scripts/avb_footer.py` was read and copied into the independent K70U evidence overlay; its verifier accepts both the third-party 64 MiB P4a image and the new K70U variant.
- K70U stock partition inventory from expdb records `boot_a` size 67,108,864 (0x4000000).
- New read-only artifact: `work/evidence-20261031/boot-rothko-uefi-evidence-20261031-avbf.img`, exactly 64 MiB, SHA-256 `2537c3b5e01b08f870dfb39a7a0836e04b24406352fdfb3b95a104be4d27a295`; AVBf v1.0, AVB0 hash descriptor 424 B, digest verified.
- It wraps the existing 307,200 B v4 body without changing header/gzip/FD. Device execution and top-level vbmeta chain acceptance remain unverified.


## Fresh device-side strings capture
- Device-side `strings` conversion and adb pull succeeded; local file is 1,152,623 B with SHA-256 `d8426a3abae05f687c5d3a638a5459a63060b7005f9167da84d5f35f7d97dd1c`.
- Four sequences contain `home key is pressed`, `boot_reason=1`, fastboot notification and `wait_for_boot_linux`; all Linux handoff markers remain absent.
- This confirms the prior binary scan with a line-oriented artifact. It does not by itself separate current from historical records or prove AVB rejection.


## Post low-check flash expdb
- Fresh strings capture records 8 KiB vbmeta and 64 MiB boot_a downloads/flashes followed by reboot.
- The next preserved LK records still stop at home-key fastboot and `wait_for_boot_linux`; no boot header/handoff markers.
- Low-check package write path is therefore evidenced, but package acceptance remains untested because LK never issued/received boot_linux event.


## stock LK detect_key reverse proof
- ELF disassembly identifies caller at `0xffff00005070dbc4` polling key indices 1 and 6.
- `0xffff00005072515c` routes home/power key checks to `0xffff000050732d10(1)`.
- Helper returns pressed when the registered hardware callback's 16-bit result is zero (`cmp w8,#0; cset w0,eq`), then caller prints home-key and returns 1.
- This places the current failure before boot image parsing and explains why the flashed low-check package produces no header/handoff markers.


## User correction on LK key segment
- Do not attribute current UEFI failure to the home-key LK segment; expdb ring history cannot bind it to the candidate execution.
- The LK patch dry-run is retained as static research only and excluded from the deliverable.
- Deliverable focus is UEFI build plus reproducible AVBf/low-check repackaging.


## Re-evaluation: MTK LK x0/DTB handoff defect
- The stock LK final call sets `x0=0xC2000115`, `x1=0x40000000`,
  `x2=0x47C80000`, `x3=0` before entering its physical-address trampoline.
  The trampoline moves those to the entry's x0..x3 in order.
- The prior K70U packer compiled the generic `uefi-sheng` BootShim. Its final
  sequence was `ic iallu; dsb; isb; br x5`; it never changed x0. Therefore the
  candidate SEC entry saved the boot magic as `gSecEntryArg0`.
- K70U's patched `ModuleEntryPoint.S` deliberately stores x0 in
  `gSecEntryArg0`, and `Sec.c` publishes that value as the DTB HOB consumed by
  Rothko DXE. The old Shim consequently supplied an invalid DTB pointer before
  GIC/display/watchdog code could help.
- The third-party rothko BootShim independently contains
  `ldr x0, =0x47C80000; br x5`, matching the stock LK `mb_dtb` reservation and
  this candidate's `LK DTB` memory descriptor. This is source-confirmed and
  reverse-confirmed, not a home-key inference.
- New `BootShim-rothko.S` adds only this device-specific x0 assignment. It
  produces a 192-byte Shim whose disassembly contains
  `mov x0, #0x47c80000` at offset 0xac; the generic reference has `br x5` at
  that offset.
- New body and AVBf images pass Android v4/gzip/ARM64/FD round-trip checks;
  AVBf hash descriptor digest is verified. Runtime execution remains untested.


## Correction after tracing the SMC boundary
The previous claim that kernel entry receives x0=0xC2000115 is withdrawn.
Stock LK loc_507118B4 executes `mov x4,#1; smc #0; ret`: the
0xC2000115 value is an SMC function ID, not proven kernel-entry data.
Stock tee.img contains its registration at ATF payload offset 0x72d08,
with handler pointer 0x4880ca28. Handler payload offset 0xca28 saves
arguments and calls 0xc2f0 to construct the nonsecure entry context.
At 0xc2f0 the 64-bit branch writes entry PC, SPSR (0x3c5 or 0x3c9),
and argument fields, so LK call-site registers cannot be equated to final
kernel-entry registers. Full dispatcher-to-context argument mapping remains
to be checked before claiming a DTB defect. The generated dtbfix images are
experimental comparison artifacts, NOT a demonstrated root-cause fix.
No device writes or boots were performed. Continue with the ATF context
mapping and then add same-boot diagnostic evidence if necessary.


## ATF audit final correction (supersedes DTB-fix hypothesis)
Saved instruction evidence: work/evidence-20261031/stock-lk/atf-smc-handoff-audit-20261031.json.
The SMC dispatcher at payload 0x2c318 captures x1 in x23 and x2 in x21;
at 0x2cafc it calls the registered handler with x0=x23, x1=x21.
Registration at 0x72d00 points SMC 0xC2000115 to handler 0x4880ca28.
For x3=1 (LK sets x4=1 before SMC), handler stores kernel as entry PC,
DTB as first entry argument and zero as second argument. The entry-context
builder copies these argument fields into the nonsecure CPU context.
Therefore generic BootShim already receives x0=DTB; the previous claimed
magic-as-DTB root cause is disproven. Default packer restored to the generic
shim. Fixed-DTB images are retained and explicitly labeled comparison-only.
The latest saved full expdb has a zero AEE header, no AEE0DEAD magic,
no TFA_DEBUG_BUF.gz section name and no gzip stream. It cannot supply a new
UEFI exception record. Missing LK strings cannot localize execution.
Next required evidence is same-attempt BootShim/SEC/DXE progress or a valid
AEE fault dump, with active-slot/readback identity. Device remains disconnected.


## Entry-only probe delivered
Built work/evidence-20261031/boot-rothko-entry-probe-7s-avbf.img.
SHA256 c302f7bb02b57e8fb77f4917a8015c18cde6a898075fc526587610ca017c0955.
64 MiB v4/AVBf, 128-byte entry shim, same 2 MiB FD retained as payload.
Probe writes only WDT LENGTH=0x3808 and RESTART=0x1971, preserves MODE,
then parks before any FD copy/SEC execution. The intended reset is about
7 seconds after shim entry. This is diagnostic, not a UEFI boot candidate.
Header, decompressed shim+FD equality and AVB digest passed offline.
A matching timing change is positive entry evidence; absence is inconclusive
because watchdog enable/access depends on hardware. No device operation done.


## Fresh device strings capture: entry probe executed (2026-10-31)
Device VKMZZDEI4H759TRS connected, current slot _a, Android boot_completed=1.
Ran strings -a on expdb on the device, then adb pull. Saved logs/device-expdb-strings-20261031-205609.txt (2042128 B), SHA256 9f5082fbde808efde82ba51502a80e4423ba476a0cf6abb1791ec02e32dbc420.
Three repeated records contain kernel_sz=0x000483da (295898, identical to entry probe compressed payload), WDT LENGTH=0x3800, and CPU PC=0x40000070, exactly the probe _Park branch at shim offset 0x70. PSTATE=0x3c5, SP=0 are consistent with the stackless EL1h entry probe. WDT time ~10.35 seconds is measured from firmware boot origin, not shim entry.
This proves the diagnostic kernel passed LK decompression and ATF handoff and executed the probe. Probe intentionally never copies FD or enters SEC; this watchdog stop is expected, not a UEFI crash. Repeated text may duplicate records, so do not infer three distinct attempts.
The same retained sequence reports vbmeta_a HASH_MISMATCH, followed by img_auth_required=0, avb_ret=0, header loads, decompression and the probe PC. Thus vbmeta validation warns but does not block this attempt. Local flags3 vbmeta is 8192 B, flags=3, SHA256 1fc27c867cc4b8045b35ad0c01c4702beeecb426f3472174ef35e75d515136b4. No device vbmeta readback hash was captured, so file identity is not asserted.
No booting-linux/final-jump strings were found in this strings capture despite actual probe execution: absence of these strings is demonstrably insufficient to claim no handoff.
Next isolate normal candidate FD copy, cache publication and SEC execution using stage-specific register/PC evidence. Do not repeat AVB-only changes as a fix.


## Stage-coded candidate
- Fresh source snapshot `/home/ubuntu/rothko-evidence-20261031/Mu-Silicium-staged`
  builds successfully with a 2 MiB FD. The staged ModuleEntryPoint feeds the
  inherited watchdog before SEC timers exist; SEC and DXE components write phase
  codes to WDT LENGTH and preserve MODE/reset routing.
- The generic BootShim remains the default and preserves ATF's x0 DTB argument.
  A separate staged Shim only adds pre-copy and post-copy WDT codes.
- Final image is a 64 MiB AVBf v4 image, SHA-256
  `18eced1a56c33b9b34d35d037cb2f8b97832f6bf704638d1cd28fa9cc7b78a16`; offline
  Android/gzip/FD round-trip and AVB digest checks pass.
- Phase table is recorded in `reports/stage-coded-candidate-20261031.md` and
  `work/evidence-20261031/stage-coded-package-20261031.json`.


## Current device partition readback (2026-10-31 22:22)
Read-only adb root readback confirms the current state independently of expdb:
- boot_a is 67108864 B, SHA256 06ad47c867ee2647856b0bb2f3e4c7b37104056facc4488891c6b2ad6474ce96.
- boot_a header is Android v4 with kernel_size=0x15141fe and kernel bytes 02 21 4c 18 (stock LZ4 Linux), not the stage-coded candidate kernel_size=0x48582 and gzip 1f8b.
- vbmeta_a is 8388608 B, SHA256 b6028bbe43a7b1d0610f8de96c3d602751bbdc46a2d7c24cb3e0f53a9a1479af. Its first 8192 bytes exactly match the flags=3 companion (SHA256 1fc27c867cc4b8045b35ad0c01c4702beeecb426f3472174ef35e75d515136b4); 56 nonzero bytes exist after that padded image.
- Therefore the low-check vbmeta is present on the device, while the stage-coded boot image is not present in boot_a at capture time. The latest expdb cannot be used as a test result for the stage-coded image.
- The historical fastboot flash records in strings show 0x4000000 downloads, but they do not identify the payload hash; current partition readback is authoritative for the present state.

## 2026-11-01 first candidate boot attribution
- User clarified the current boot_a readback is after restoring stock; it must not be used to judge the failed candidate attempt.
- First candidate window is expdb.strings lines 5548-6362, immediately after the first flash:boot_a at line 5422 and reboot at line 5547.
- The window has LASTPC CPU0 pc=0xD66D9BC939608AEC, WDT_INIT=2, RAM_CONSOLE wdt status 0x800, and final Boot dev init=299.
- It has no starting app mt_boot, wait_for_boot_linux, Ready to boot linux, boot header/decompression, boot_linux_fdt, or UEFI marker.
- Therefore this attempt stopped in preloader/BL2 before observable LK entry. The later boot_a stock readback only reflects the user's restoration and is not evidence against the candidate attempt.


## Upstream Silicium-Rothko (2026-11-02, external repository)

Treat all of this as external data, graded by source.

- Repo is private; `ChallengeThePeak` is an organization with 0 public repos.
  SSH works from WSL as `woaphone`; HTTPS anonymous gives 401/404.
- Windows proxy facts measured on this host: `127.0.0.1:55376` (the value in the
  environment) is NOT listening; the live proxy is Clash on `127.0.0.1:7897`.
  WSL (NAT, gateway 172.30.32.1) cannot reach host loopback, so a plain TCP
  relay on 0.0.0.0 plus an ssh ProxyCommand CONNECT helper is required.
- Branches: `main` (docs/tools), `uefi/rothko` (uefi-mtk-reference platform),
  `basecore/rothko` (Mu_Basecore). Tags: rothko-avb-v1 2e21155,
  rothko-trace-v2 949afd3, uefi-avb-v1 4677e07, uefi-trace-v2 8ec4559,
  basecore-avb-v1 cd48f4d, basecore-trace-v2 9918480.
- Upstream README and BUILD_PSTORE_BOOT.md state the firmware reaches DXE Core
  and stops at `ASSERT [DxeCore] Gcd.c(2420): Found`, with the last visible
  stages being MMU enabled, HOB list 134 entries, FV decompressed, loading
  DxeCore at 0x0040E58000 EntryPoint=0x0040E5A800.
- The logging channel is pstore: PstoreLog in Sec.c, DebugLib ->
  BaseDebugLibSerialPort, SerialPortLib -> FrameBufferSerialPortLib
  (Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib), pstore at
  0x48090000+0xE0000, pmsg at 0x480F0000+0x80000, read via
  /sys/fs/pstore/pmsg-ramoops-0 after restoring Android.
- Upstream rothkoPkg members: DeviceBuild.py, Include/APRIORI.inc,
  Include/DXE.inc, Library/MemoryMapLib/{MemoryMapLib.c,.inf}, README.md,
  UniXNUComponents.dsc.inc, UniXNUComponents.fdf.inc, UniXNUConfig.dsc.inc,
  rothko.dsc, rothko.fdf. No Drivers/ directory.
- Our Mu-Silicium trees instead carry Drivers/RothkoDisplayDxe and
  Drivers/RothkoWatchdogDxe and no UniXNUComponents includes; whole-tree grep
  for PstoreLog / K70U_UEFI_PSTORE_BEGIN returns nothing.
- Consequence: the FV membership defect fixed at 544ac2d6 is specific to the
  local lineage. It is not an upstream divergence and upstream never needed it.
- Upstream open gates (self-declared): Gcd.c(2420) DXE memory/HOB attributes;
  UFS quiesced by LK's ufs_deinit before direct UEFI; 8 MiB init_boot too small
  for a full XNU payload; no existing MT6989 UniXNU port; panel/touch/PMIC/GPU/
  Wi-Fi/audio variants unidentified; AVB tail preservation is not a re-sign.
