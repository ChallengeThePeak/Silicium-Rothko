# Progress Log

## Session: 2026-10-31 Asia/Shanghai

### Phase 1: Baseline And Evidence Inventory
- Status: in_progress.
- Read planning-with-files and reverse-engineer-anything SKILL.md completely.
- Read planning resolver/initializer/templates and REA native, evidence, and
  connection-recovery references.
- Performed shallow, explicitly bounded inventories of the current workspace,
  parent project, and user-selected stock image directory.
- Created these three task-owned files with apply_patch.
- Did not run the planning initializer because it includes deletion branches.
- No image was built, overwritten, flashed, or executed.
- Resolved this explicit PLAN_ID with the installed read-only resolver.
- Recorded parent HEAD and relevant-directory diff baseline.
- Started three user-authorized independent workers: failure_logs, stock_lk,
  and uefi_contract. Each has separate report/output ownership.
- Confirmed existing REA CLI version/help without enabling its MCP server.
- Read project red lines and historical handoffs; no QEMU or device action.
- Initial worker observations were added to findings with provisional labels.

### Phase 2/3: Evidence Reconstruction And Candidate
- Status: in_progress.
- Root independently verified original DTB GIC reg cells.
- Worker validated image 23's AEE section table and actual ATF fault/WDT state.
- Created a new overlay copy, initialized its separate Git history, and saved
  baseline commit 1f6ff76 before editing copied source.
- Copied the existing ext4 source to a new workspace without build caches.
  Saved full hashed inventory and baseline local source commit 9e130c47.
- Added deletion-free preparation and fresh-build scripts.
- Implemented targeted GIC, MMIO, watchdog separation, and display bounds fixes
  in the independent overlay. The first pre-sync build was retained as a
  diagnostic record; the final build is recorded below.
- Rate-limited workers were resumed through their existing canonical tasks
  after the user's explicit request. No replacement agents were spawned.

### Phase 3/4/5: Fresh Build, Regression, And Delivery
- Synchronized the overlay into the ext4 build source after detecting that the
  first build used a pre-edit snapshot; the old files were copied to
  `_quarantine/sync-20261031-1455` before replacement.
- Created fresh source snapshot `/home/ubuntu/rothko-evidence-20261031/Mu-Silicium-build2`
  with preparation manifest `work/evidence-20261031/build-preparation-02.json`.
- Built with Ubuntu2404, clang 18.1.3, DEBUG/CLANGPDB, AARCH64, FD base
  `0x42000000`, size `0x200000`; build returned 0 and produced a 2 MiB FD.
- Build source commit: `10a14f37eb327477deb7b4f9b45b9381743aaef4`.
- Final firmware SHA-256:
  `65450d31fd30072e02ceab512d4f1fb1e64a5f66732267ed16d6527051001f44`.
- Build report names both `RothkoWatchdogDxe` and `RothkoDisplayDxe`; the
  build log has zero `error:` matches and one pre-existing library-class warning.
- `check-memmap-alignment.py` passes every descriptor at 4 KiB alignment.
- Final report written to `reports/evidence-20261031-uefi-candidate.md`.
- Windows overlay commits are `af0802a2` (platform/display/memory fixes) and
  `f81957e6` (watchdog DXE); the overlay worktree is clean after these commits.
- Packaged Android boot v4 image with the existing BootShim. The `.img` is
  307,200 bytes, SHA-256
  `a9b39f2a29dc06a401c1fc52b490f4c931bed5f3609c097acdf3d28e941f76a9`, and
  `verify-bootimg.py` returned `result: OK`.

## Test Results
| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Supplied stock directory inventory | Explicit path exists | Listed stock boot-chain images | PASS |
| Plan initializer safety inspection | No deletion during this task | Initializer has deletion branches; not executed | SAFE FALLBACK |
| Parent Git baseline | Identify unrelated existing changes | HEAD/recovery-main recorded; unrelated dirty files preserved | PASS |
| Candidate source baseline | Identify existing source history | ext4 build tree is not a Git repository | SNAPSHOT REQUIRED |
| Build host readiness | Existing project distribution/toolchain | Ubuntu2404, clang 18.1.3, ample ext4 space | PASS |
| Original DTB GIC reg cells | Standard distributor/redistributor | 0xc400000/0xc440000, confirming old PCD mismatch | PASS |
| Fresh source snapshot | Preserve originals and record identity | 44,489 files/links, full hash inventory, local checkpoint | PASS |

## Error Log
| Error | Attempt | Resolution |
|-------|---------|------------|
| REA MCP tools absent from active tool set | 1 | Will use the existing CLI, without enabling REA MCP. |
| git status on ext4 source returns not a repository | 1 | Preserve snapshot; do not invent commit identity. |
| uefi_contract and failure_logs API rate limit | 1 | Resume the same tasks after backoff; retain reports and tool artifacts. |
| Incorrect inferred ArmGic/RamManager source filename during bounded reads | 1 | Shallow-listed the exact known directories and used actual filenames. |

## Recovery Check
| Question | Answer |
|----------|--------|
| Where am I? | Phase 2 |
| Where am I going? | Failure proof, correction, offline review, delivery |
| What is the objective? | Stock-LK-grounded K70U UEFI candidate and evidence |
| What is known? | See findings.md |
| What has been done? | Skills read, bounded inventories, isolated plan |


### 2026-10-31: 正常/失败 fastboot 分支逐行对照
- 读取正常 `/proc/pl_lk` 上下文并扫描失败完整 expdb 关键字符串。
- 发现正常记录也经 fastboot app 和 `wait_for_boot_linux`；正常在此后有 `Ready to boot linux...`，随后加载 boot headers、解压并跳转。
- 失败的两组各自包含 home-key pressed / boot_reason=1 / notify_enter_fastboot；未发现 Ready-to-boot-linux、boot header load 或 `boot_linux_fdt`。
- 已更新两个 handoff 报告，撤回“wait_for_boot_linux 单独证明未加载候选”的过度结论。


### 2026-10-31: Third-party boot construction review
- Read handoff-stage README/status, LK kernel-load and bootimg-path docs, stage1 runbook, boot JSON and manifest. All 14 manifest-listed binary/build outputs hash-match.
- Confirmed raw blackbox_r8/expdb_r8 artifacts are not part of the bounded package inventory; L1/L2 claims remain secondary documentation.
- Compared v0 legacy recipe to K70U v4 candidate and normal `/proc/pl_lk`; wrote migration assessment to `reports/handoff-stage-boot-packaging-review-20261031.md`.


### 2026-10-31: AVBf candidate generated
- Read the third-party AVB footer implementation and its build notes tying missing AVBf to LK image-table rejection.
- Confirmed K70U `boot_a` is 0x4000000 bytes from saved LK partition inventory.
- Added independent `avb_footer.py` and `add-avb-footer.py` to the evidence overlay.
- Generated and verified a separate 64 MiB K70U AVBf image; original body and source candidate remain preserved.


### 2026-10-31: device-side expdb strings pull
- Confirmed device `VKMZZDEI4H759TRS`, bootreason `reboot`, bootmode `normal`.
- On-device root ran `strings -a /dev/block/by-name/expdb`; pulled via adb to `device-expdb-strings-20261031-1717.txt` (1,152,623 B, SHA-256 `d8426a3abae05f687c5d3a638a5459a63060b7005f9167da84d5f35f7d97dd1c`).
- Fresh text contains four home-key/fastboot/mt_boot/wait sequences and zero Ready-to-boot-linux, header-load, boot_linux_fdt, booting-linux, or final-jump markers.


### 2026-10-31: post-flash expdb strings capture
- Fresh device strings file pulled: 1,708,767 B, SHA-256 `964ac86eaee035f7c84cae922325db2d4b9b9805ed371b6eefebb298575bed71`.
- Expdb records `download:00002000`/`flash:vbmeta_a` and `download:04000000`/`flash:boot_a`, each followed by reboot.
- After those writes, six home-key/fastboot/mt_boot wait sequences remain; all boot header and Linux handoff markers are absent.
- This materially strengthens the conclusion that the current blocker precedes AVB/header/UEFI execution.


### 2026-10-31: detect_key static reverse proof
- Parsed the stripped LK ELF program segment with Capstone and reconstructed string xrefs.
- Located the home-key log at `0xffff0000507251e0`, its caller/poller at `0xffff00005070dbc4`, and hardware callback helper at `0xffff000050732d10`.
- Confirmed the helper's zero-result-to-pressed inversion and recorded the pre-boot position of this branch.


### 2026-10-31: package pipeline hardening
- User correction accepted: home-key LK text is not treated as the UEFI failure cause; LK patch dry-run is excluded from the solution.
- Added `pack-bootimg-rothko-avb.py`, which emits the v4 body plus AVBf by default and refuses output/body overwrite.
- Existing 64 MiB AVBf boot and flags=3 vbmeta artifacts remain the current offline low-check package.


### 2026-10-31: re-evaluation and DTB argument fix
- Re-read the stock LK final trampoline assembly. It passes x0=0xC2000115,
  x1=0x40000000, x2=0x47C80000, x3=0 to the decompressed kernel entry.
- Confirmed the previous candidate used the generic `uefi-sheng` 192-byte Shim,
  whose final instruction was `br x5`; it preserved x0 and therefore fed the
  boot magic into K70U SEC's `gSecEntryArg0` instead of the DTB address.
- Added `scripts/BootShim-rothko.S`, which sets x0 to the confirmed K70U DTB
  reservation `0x47C80000` immediately before entering the FD.
- Generated preserved DTB-fix body and AVBf images. Body SHA-256 is
  `4181600fa31f7007e53510d08aa7f5ccb892f81c9a3b5a8e2cc7526d1f8ffe23`; AVBf
  SHA-256 is `41b2279af185232c22fcce61d83d764f4abd21f1df7c760f716cfd10c638de68`.
- Both images pass the updated verifier; AVBf digest verification passes.
- No device is connected and no device write/boot/reset was performed.


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


## Stage-coded normal candidate
- The 7-second entry probe was confirmed by expdb: PC `0x40000070` matched its
  park loop and `kernel_sz=0x483da` matched its gzip payload.
- Built a fresh staged source snapshot with early WDT feed, SEC phase markers,
  SEC exception LR beacon, ArmGicDxe/TimerDxe/WatchdogDxe markers, and display
  phase markers. Build returned 0; final FD SHA-256 is
  `d55a4f9d5cb5a85475c810f8b4824ac50a0c723486e667ee867650b30a847948`.
- Packaged one normal v4+AVBf image using the generic DTB-preserving BootShim.
  Image SHA-256 is
  `18eced1a56c33b9b34d35d037cb2f8b97832f6bf704638d1cd28fa9cc7b78a16`.
- Updated verifier to infer Shim length from the ARM64 image header; the new
  256-byte stage Shim and all prior 192-byte images pass.
- No device write or boot was performed. This is the single image for the next
  controlled test; its last WDT LENGTH value identifies the last phase reached.


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


## Current device partition readback (2026-10-31 22:22)
Read-only adb root readback confirms the current state independently of expdb:
- boot_a is 67108864 B, SHA256 06ad47c867ee2647856b0bb2f3e4c7b37104056facc4488891c6b2ad6474ce96.
- boot_a header is Android v4 with kernel_size=0x15141fe and kernel bytes 02 21 4c 18 (stock LZ4 Linux), not the stage-coded candidate kernel_size=0x48582 and gzip 1f8b.
- vbmeta_a is 8388608 B, SHA256 b6028bbe43a7b1d0610f8de96c3d602751bbdc46a2d7c24cb3e0f53a9a1479af. Its first 8192 bytes exactly match the flags=3 companion (SHA256 1fc27c867cc4b8045b35ad0c01c4702beeecb426f3472174ef35e75d515136b4); 56 nonzero bytes exist after that padded image.
- Therefore the low-check vbmeta is present on the device, while the stage-coded boot image is not present in boot_a at capture time. The latest expdb cannot be used as a test result for the stage-coded image.
- The historical fastboot flash records in strings show 0x4000000 downloads, but they do not identify the payload hash; current partition readback is authoritative for the present state.

### 2026-10-31: expdb latest five-record split
- Re-read device-expdb-strings-20261031-221732.txt as one expdb history,
  rather than treating the whole strings file as one boot.
- Five [SEC] Loading SEC config boundaries were found; the exact split and
  marker counts are saved in
  work/evidence-20261031/logs/expdb-recent-five-20261031.json.
- Record 1: 64 MiB boot_a fastboot write, home-key branch, then LK wait.
- Record 2: original boot reaches Ready, all three v4 headers, stock
  kernel_sz=0x015141fe, and kernel decompression; vbmeta hash mismatch is
  logged but auth is disabled for this flow.
- Record 3: AEE/WDT history (wdt_status=0x8000, TFA_DEBUG_BUF.gz,
  SYS_CUR_PLLK, blackbox index 0/dump_count 3), with no UEFI PC in strings.
- Record 4: 64 MiB boot_a fastboot write, then LK wait only, AEE status 0x2.
- Record 5: 64 MiB boot_a fastboot write, home-key branch, LK wait, then AEE
  status 0x6/exp_type 1 and blackbox index 3/dump_count 2.
- This is the requested five-record evidence and keeps historical AEE/home-key
  data separate from a demonstrated UEFI runtime failure.

### 2026-11-01: offline root-cause proof and confirmed package
- Independently rechecked the historical AEE23 beacon and the DxeCore map:
  CoreFreePoolI contains the pool-head load at RVA 0x7bc8, and the
  encoded FAR 0xfffffffffffffff1 implies FreePool((VOID *)9).
- Rechecked the staged DxeCore output. CoreFreePool contains the lower-bound
  and alignment gates before calling CoreFreePoolI; BmConsole,
  GraphicsConsole, reset suppression, SEC entry, GIC and watchdog fixes are
  present in the staged source/build.
- Repacked the staged FD and staged BootShim into
  boot-rothko-uefi-confirmed-20261101-avbf.img.
- Android v4/gzip/FD round-trip, AVBf digest, image hash, and stage-immediate
  disassembly checks pass.
- Runtime device proof remains intentionally open because this exact new
  image has not been flashed in this session.

### 2026-11-01: Fresh WDT keepalive delivery
- User requested direct image delivery without another verification pass.
- Delivered existing fresh build: boot-rothko-uefi-confirmed-20261101-avbf.img plus flags=3 vbmeta companion.
- Hardware retest remains user-controlled; test instructions use one flash/reboot and one strings pull.

### 2026-11-01: First post-flash expdb attribution
- Isolated lines 5548-6362 after the first candidate flash/reboot, before the later restoration.
- Classified the stop as preloader/BL2 watchdog reset: WDT_INIT=2, status 0x800, last marker Boot dev init=299; no LK or UEFI markers.

### 2026-11-01: Continuation And Attribution Audit
- Read the user-referenced chat and all three selected planning files; retained
  the distinction between the failed candidate and subsequent stock restoration.
- Resolved the task plan using the installed read-only PowerShell resolver.
- Recorded scoped Git baseline and preserved the existing verifier modification.
- Reopened log attribution because missing strings and a reset-status sample
  do not alone prove the candidate stopped in preloader/BL2.
- Added phases 11-13 for log-store reconstruction, candidate provenance/focused
  repair, and offline regression. No phone command or artifact overwrite run.
- Added an in-memory tested fragment parser; all 10 tests pass. Preserved the
  original input, fragment metadata, and two flash-adjacent excerpts in a new
  evidence directory. Confirmed an exact 813-line duplicated early prefix.
- Normal /proc/pl_lk provides a direct counterexample to the prior WDT/status
  diagnosis. The last preloader-before-LK root-cause claim is withdrawn.
- Read-only independent candidate audit confirms old/new image equality, a
  compiled watchdog cutoff, a stale build-result hash, and unsafe unbuilt
  MODE/NONRST edits. Next source change is only removal of the callback cutoff.
- Checked physical host storage before source copying: Ubuntu2404 is on C:,
  not nearly-full D:. Large new build data stays in ext4.

### 2026-11-01: Real Fresh Keepalive Build
- Prepared a new Build-free source snapshot at
  /home/ubuntu/rothko-evidence-20261101/Mu-Silicium-keepalive-clean.
  Inventory covers 44502 files/links; digest
  8c0424641715f5e810ebaf8a2e7d778816a46b0df8aff1fc6afa8512477db0a3.
- Baseline commits b365a73769063173884e5f3ed570fe8b213a9f24 and dbbf738;
  the second explicitly versions the inherited RothkoStage header.
- Applied only the watchdog cutoff removal with git apply --check, preserved
  the old source in its baseline history, and committed
  0b5a75c6716108d4458470938c265b186da7a07e.
- Build wrapper now accepts an explicit build label and a clean-tracked-source
  gate, and records the source status and its own script hash.
- Fresh build build-01 returned 0 in 34 seconds. FD is 2097152 bytes, SHA-256
  2c7e7c5179a6781b2e7f69fa55ea70c9ee5d18835cd151e9e8d4482a5bdd3c42.
  This differs from the delivered old FD; no old Build output was copied.
- Separate actual-source host tests and final packaging are in progress.

### 2026-11-01: Regression And Publication Complete
- Log parser tests: 10/10 pass. Watchdog actual-source GCC ASan/UBSan tests:
  7/7 pass, with an old-source negative control reproducing 599-write starvation.
- New module disassembly confirms the linked callback has no diagnostic counter.
- Bound build result/log/source/test hashes and v4/gzip/AVBf round trip in
  work/evidence-20261101-continuation/keepalive-release.json.
- Published one new 64 MiB image, SHA-256
  01261519293e9ef62756565ccbf94f156a7776145c53edd30858e55e6888bfc6.
  Old images and the pre-existing overlay verifier edit remain untouched.
- Updated continuation report and added an explicit superseding correction to
  the old root-cause/fresh-build report. No device operation, deletion or shutdown.
- Runtime root cause remains open; offline continuation phases 11-13 are complete.
- Verified local evidence commit 38e2ac116a3bcb9a1a1f0ed44ed82b4ba27efbb1 in
  keepalive-clean-records; it preserves build logs/results, source inventory,
  actual-source tests and 20 selected project-file snapshots. All copied Python
  scripts parse successfully. Source fix remains separately committed at 0b5a75c.
- version-checkpoints.json records both histories without changing the parent
  recovery-main repository or committing unrelated user changes.

### 2026-11-01 11:06: New User-Authorized Expdb Capture
- User requests the new raw expdb after a failed candidate boot and subsequent
  stock restoration (stock failed once, then booted). Candidate-only attribution
  is required; do not conflate these later boots or speculate about NoGZ.
- adb confirms the expected single K70U. No reboot, flash, erase, or slot change
  was issued. Prior build processes are already completed; no interrupted build
  is being silently resumed.
- Captured full expdb through root stdin-file commands and host binary streaming,
  without creating phone files. Corrected verified KernelSU newline expansion;
  recovered 128 MiB exactly matches the device before-hash. Retained both transport
  and recovered raw bytes. Phone disconnected before optional post-hash.
- Located unique new-candidate kernel-size marker 0x48552 and LK decompression
  record. Current work isolates that fragment and the adjacent flash/restore
  context instead of treating unrelated restored-stock boots as candidate tests.
- Extracted candidate-only raw/text at 0x7f21400..0x7f55400, with preceding
  flash 0x7f0f862 and following restoration context 0x7fbeacc. Published its
  offset-preserving text and selection.json under the new capture/test-boot-01.
- Independent full-file AEE audit confirms absent magic/gzip/payload, not just
  missing strings. Only kedump progress metadata remains; no invented PC/FAR.
- Wrote reports/new-expdb-test-boot-20261101.md. Both nonmatching stock-size
  records are excluded from candidate attribution. No NoGZ causal speculation,
  no new firmware build, no further device interaction after disconnect.

### 2026-11-01: User Requests Persistent LK Correction And UEFI Reverse Trace
- User explicitly requests AGENTS.md record that LK executed candidate loading
  and previous preloader attribution was a log-reading error.
- Confirmed local AGENTS.md/CLAUDE.md did not exist, then created the scoped
  K70U AGENTS.md, inheriting environment/safety rules rather than duplicating them.
- Source checkpoint remains 0b5a75c with clean tracked state; evidence history
  is 48483749e722b1b06c69d87b81f324085d614ddc before this new analysis.
- Opened phases 16-18 for a binary-backed UEFI-side trace, not further device
  operations or renewed NoGZ/preloader speculation.
- AGENTS.md is checkpointed at 59507066. Fresh SEC/map/FD/Shim inputs are copied
  with hashes, and direct IDALIB/Hex-Rays output is saved as sec-ida.json.
- REA provider unavailability did not trigger configuration repair or MCP enable.
- Found and documented the decompiler's mutable-.text/entry-argument folding
  trap before using its pseudocode as evidence. Binary instructions remain
  authoritative for the x0 save and pre-stack calls.
- Parallel independent scopes are GIC/Timer/final LK quiesce and display/FV
  binding; root owns BootShim/SEC/cache/MMU and all shared planning updates.
- Found a concrete integration error: the tested FD has no display/watchdog
  executable FFS, despite generated .efi files and APRIORI GUID entries.
  Independent container traversal, Fv file lists and source agree.
- Root verified BaseTools writes only priority GUIDs and the dispatcher schedules
  discovered files; the old DXE.inc comment caused an actual omission.
- Prepared fresh Build-free source and changed only DXE.inc (two INF entries and
  the false comment), preserving driver code and APRIORI order. Fix checkpoint
  544ac2d6980f0d68cc4159bd04c1f24e94c928b3. Fresh build-01 is running.
- Added this confirmed packaging defect to AGENTS.md. Neither the fixed source
  nor the upcoming image is described as an observed successful UEFI boot.
- Fresh FV-fix build returned 0; FD is 38edb952ea4501f78871ed8454c3d4ce4a8e1c1013dd4f0dd21fa32fdb94ffdc.
  Actual new FD contains display and watchdog executable FFS exactly once each,
  both PE payloads equal their current linked files, and no APRIORI references dangle.
- Final published boot was unpacked and independently checked again by the new
  mandatory FV publication gate; image hash
  ef6dacb910a7edd646cb68c45c60b014bef4d84996dd95196216bcd42f2953c5,
  kernel_size 0x49fba. Old images remain unchanged; no device operation occurred.
- FV checker regressions pass 8/8. GIC/Timer audit proposes no new speculative
  register fix; corrected LK tail helper addresses are 0x50783bc0 and 0x50795220.
- Updated AGENTS.md with old-tested/new-untested identity separation and wrote
  reports/uefi-fv-membership-fix-20261101.md. Offline phases 16-18 are complete.

### 2026-11-01: Supplied expdBUEFIBX
- User supplies one new file; inferred continuation is file-only analysis.
- Re-read K70U AGENTS.md, resolved the existing plan and checked clean fvfix source.
- Hashed the 640127-byte ASCII input. It has two flash/reboot records but no
  initial kernel/UEFI fault anchors. A bounded fragment assessment follows;
  prior LK-loading proof remains valid and is not negated by missing new text.
- Existing tested parser preserved and split the input: seven text fragments,
  two flash-adjacent slices, and one exact 813-line repeated prefix.
- Wrote the evidence-limited report and updated AGENTS.md to distinguish lack
  of a matched runtime record from an assertion that no test occurred.
- No device access, firmware edit or build was performed; complete raw data
  from this attempt is needed before further exception localization.


### 2026-11-02 00:20: Upstream Silicium-Rothko Cloned And Compared
- User supplied the private repo ChallengeThePeak/Silicium-Rothko. Anonymous HTTPS
  returned 401/404 (organization, public_repos=0). WSL SSH key works; clone first
  stalled at ~30 KB/s and died at 58% (early EOF).
- Routed the clone through the Windows proxy without touching Windows config:
  Python TCP relay 0.0.0.0:15537 -> 127.0.0.1:7897 (Clash mixed port; the
  env-provided 127.0.0.1:55376 is dead and never listening), plus a WSL
  CONNECT helper used as ssh ProxyCommand. Speed went to ~2.5 MB/s.
- Cloned main (6b1f2dd) plus a sparse partial clone of branch uefi/rothko
  (3b33638) into /home/ubuntu/rothko-upstream-20261102. Also fetched tags
  rothko-avb-v1 (2e21155) and rothko-trace-v2 (949afd3), both dated 2026-11-01
  afternoon, i.e. after this plan's last update at 12:21.
- Upstream documents real device pstore output reaching DXE Core and stopping at
  ASSERT [DxeCore] Gcd.c(2420): Found. That is far past our best runtime proof
  (entry-probe PC=0x40000070 in the shim).
- Decisive lineage check: upstream rothkoPkg has 11 files including
  Library/MemoryMapLib and UniXNUComponents.dsc/fdf.inc, and NO Drivers/
  directory; our Mu-Silicium trees ship RothkoDisplayDxe/RothkoWatchdogDxe and
  carry no pstore code at all (whole-tree grep for PstoreLog is empty).
- Therefore the FV membership defect we fixed is local-lineage only: upstream
  never had those two drivers, so "did upstream fix it" does not apply.
- Wrote reports/upstream-silicium-rothko-compare-20261102.md. No device
  operation, no flash, no change to existing local source trees or images.

### 2026-11-02 00:30: Upstream Packaging Chain Read
- Read tools/boot_v4.py (378 lines), BOOT_CONTAINER_AUDIT.md and BootShim/BootShim.S
  from the cloned upstream to answer how its images actually get accepted.
- Three container decisions: reuse the stock 4 KiB v4 header and only patch the two
  size fields; preserve the whole AVB tail from 0x1000+align(kernel)+align(ramdisk)
  instead of zero-filling it; compress with legacy LZ4 rather than gzip.
- Payload split: boot carries legacy-LZ4(BootShim+2MiB FD), init_boot carries a
  raw 1 MiB FAT12 ramdisk; kernel_target is read from vendor_boot offset 16.
- BootShim copies the FD to FD_BASE in 16-byte chunks, cleans D-cache by CTR_EL0
  line size, invalidates I-cache, then branches. The wrapper now normalizes
  text_offset to kernel_target % 0x200000 and sets flags 0xA, and rejects a FD copy
  target that partially overlaps the live image.
- Appended section 7 to reports/upstream-silicium-rothko-compare-20261102.md.
  No device operation; the audit's own caveats (footer causality unproven, tail
  preservation is not a re-sign) are carried into the report verbatim.

### 2026-11-02 01:23: Upstream UEFI FD With pstore Built And Packed
- Went the documented upstream route only: DeviceBuild.py + stuart. No bypass build.
- External deps resolved: Mu-Basetools v2026080000.0.0-rc0, OneCrypto 1.1.2 (both via
  retries), mu_nasm 20016.1.1 supplied by the user and served from the NuGet
  global-packages cache (~/.nuget/packages/mu_nasm/20016.1.1).
- mono 6.8 installed without root by extracting Ubuntu debs into ~/mono; requires
  MONO_CFG_DIR=/home/ubuntu/mono/etc for NuGet.exe to resolve System.Native.
- /home/ubuntu/UniXNU was switched to 67df14de (previous HEAD fb2bb31 recorded in
  /home/ubuntu/unixnu-head-before.txt) because DeviceBuild.py resolves
  ../../UniXNU/package relative to the workspace, not via any symlink.
- One upstream inconsistency had to be corrected to build at all:
  UniXNUConfig.dsc.inc sets PcdUniXNURamDiskOffset/Size, but no DEC in UniXNU
  (including latest a4419c8) declares them and UniXNURamDiskDxe does not use them.
  EDK2 fails with error F001. The two lines were commented out, original backed up
  under /home/ubuntu/quarantine.
- Build result: PROGRESS - Success. FD 2097152 bytes,
  sha256 b4dc51d1975e9d343ce449875bb046c52ccb66059544b9162cacd52408d758eb.
- Packed with upstream tools/boot_v4.py (legacy LZ4, --preserve-avb-tail).
  boot e9847903..., init_boot 933acc53..., AVB tail byte-identical to template,
  decoded payload equals shim(192B)+FD exactly.
- Templates are OS1.0.22 (only complete stock set on this machine), not 3.0.303.
  No device operation was performed; image is untested on hardware.
- Report: reports/uefi-pstore-build-20261102.md
