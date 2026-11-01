# Task Plan: K70U UEFI Bring-Up From Stock LK Evidence

## Goal
Correlate prior K70U failures with the supplied stock boot-chain binaries,
implement a narrowly justified independent UEFI candidate, and deliver its
reproducible offline verification and honest remaining device-test limits.

## Plan Binding
- PLAN_ID: 2026-10-31-k70u-uefi-lk-evidence
- PWF_PLAN_ROOT: D:/漏洞/UNIXNU/适配K70U
- Owner: root. Workers report in separate files; only root updates this plan.
- No lifecycle hooks are claimed to be active.

## Next Step
Upstream Silicium-Rothko (private, cloned 2026-11-02) documents real device
pstore logs reaching DXE Core and stopping at ASSERT [DxeCore] Gcd.c(2420).
Our line proves only shim entry. Choose between adopting the upstream
uefi/rothko route, or porting only its pstore logging into the local
Mu-Silicium trees. No device operation is authorized by this comparison.

## Current Phase
Phase 21 complete (upstream cloned and compared; route decision pending user)

## Phases

### Phase 1: Baseline And Evidence Inventory
- [x] Read applicable project instructions and current handoffs.
- [x] Record branch, commit, and pre-existing changes.
- [x] Inventory bounded log/source/output paths and stock image identities.
- [x] Assign independent investigations with non-overlapping write ownership.
- **Status:** complete

### Phase 2: Failure And Boot-Contract Reconstruction
- [x] Extract exact failure stage and register/address evidence from logs.
- [x] Decompile supplied MTK LK handoff, boot header, DTB, and memory contract.
- [x] Distinguish alternate boot-layer LK from the stock MTK LK.
- [x] Cross-check hypotheses against original file bytes and source.
- **Status:** complete

### Phase 3: Independent Corrected Candidate
- [x] Select only changes justified by evidence.
- [x] Preserve previous candidates and stock inputs.
- [x] Implement/build in the authorized WSL distribution and fresh paths.
- [x] Produce traceable image and build manifest.
- **Status:** complete

### Phase 4: Offline Regression And Independent Review
- [x] Test header, placement, relocation, DTB, RAM, and entry contracts.
- [x] Confirm the build report contains the intended DXE modules and the firmware is 2 MiB.
- [x] Review the preserved worker reports and source/build evidence.
- [x] Record unresolved hardware-only claims without overstating validation.
- **Status:** complete

### Phase 5: Delivery
- [x] Write concise Chinese evidence report with exact source references.
- [x] Publish candidate paths, hashes, and bounded test instructions.
- [x] Explicitly distinguish measured, source-confirmed, inferred, and blocked.
- **Status:** complete

## Constraints
- No deleting files or directories, including cleanup invoked by scripts.
- Read an existing file before changing it; preserve unrelated changes.
- No disk-wide recursive discovery.
- No device writes, flashing, formatting, or shutdown.
- A device boot is not authorized by this request.
- Building and packing Linux-dependent outputs must occur in WSL.
- Do not promise a first-try hardware boot from offline evidence alone.
- Stock source is the user's explicitly supplied I:/rothko_images.../images.
- New capture request authorizes adb/root reads of expdb and local evidence
  creation only. Do not flash, erase, reboot, change slots, or write partitions.

### Phase 11: First Post-Flash Evidence Reassessment
- [x] Read the referenced chat and resolve this existing plan explicitly.
- [x] Record current Git state; preserve the existing verify-bootimg.py edit.
- [x] Preserve/hash the user-supplied strings capture and identify log-store boundaries.
- [x] Separate duplicated/stored PL buffers, LK runs, and reset-cause history.
- [x] Correct any conclusions that exceed the capture's coverage.
- **Status:** complete; actual execution stop remains unknown from this strings-only capture.

### Phase 12: Delivered Candidate And Focused Repair
- [x] Audit delivered image identity versus staged and fresh keepalive sources.
- [x] Trace actionable source defects independently of missing log markers.
- [x] Apply a bounded correction in a new source/output path if justified.
- **Status:** complete; fresh build succeeds with only the cutoff removed and a new build label.

### Phase 13: Regression And Handoff
- [x] Exercise log parsing and any changed code with reproducible offline tests.
- [x] Record artifacts, hashes, limitations, and remaining hardware-only evidence.
- [x] Prepare the evidence-graded handoff and a real fresh-built image.
- **Status:** complete; device execution and the original early failure remain unproven.

### Phase 14: Fresh Raw Expdb Capture
- [x] Record the user's exact candidate/stock-restoration timeline.
- [x] Confirm the connected K70U and bounded local capture storage.
- [x] Capture the complete raw expdb without overwriting prior captures.
- [x] Record size, hash, command, and capture metadata.
- **Status:** complete; full bytes match the device before-hash, optional after-hash unavailable after disconnect.

### Phase 15: Candidate-Only Runtime Attribution
- [x] Validate AEE/log-store structures and preserve binary offsets.
- [x] Separate candidate execution from later restoration attempts.
- [x] Match positive kernel-loading evidence; explicitly record missing PC/stage proof.
- [x] Report only proved observations and explicit coverage gaps.
- **Status:** complete; candidate LK loading is observed, exact BootShim/UEFI stop remains unknown.

### Phase 16: Persistent Project Correction
- [x] Read/confirm absence of local AGENTS.md before creating it.
- [x] Write confirmed LK-loading evidence and withdraw the wrong log attribution.
- [x] Save a local version checkpoint without touching unrelated parent work.
- **Status:** complete; AGENTS.md checkpoint 59507066c8711833d3e5c27358b9eec5d8251abc.

### Phase 17: Actual UEFI Binary And Source Trace
- [x] Bind the analysis to the delivered new FD/modules and known stock handoff.
- [x] Trace BootShim -> SEC entry, cache/stack/MMU/HOB initialization.
- [x] Independently audit GIC/Timer/display contracts against actual supplied evidence.
- [x] Identify definite code defects or state precise remaining proof limits.
- **Status:** complete; actual FD omits both required custom drivers despite APRIORI references.

### Phase 18: Bounded Correction Or Evidence Handoff
- [x] Implement only an evidenced correction, if a definite defect is found.
- [x] Test/rebuild only changed behavior using preserved new paths when needed.
- [x] Persist reverse evidence, source references, and honest runtime limits.
- **Status:** complete; source 544ac2d6980f0d68cc4159bd04c1f24e94c928b3, new boot ef6dacb9..., not device-tested.

### Phase 19: New Supplied Text Evidence
- [x] Read project rules and hash the exact user-supplied file.
- [x] Determine whether the file contains raw partition/container data.
- [x] Preserve input and analyze bounded text fragments/duplicates.
- **Status:** complete

### Phase 20: Evidence-Limited Result
- [x] Check for fvfix kernel-size or UEFI runtime anchors.
- [x] Separate observations from absent capture coverage.
- [x] Persist findings without a new speculative firmware change or device operation.
- **Status:** complete; input is insufficient for a new UEFI stop-point attribution.

### Phase 21: Upstream Silicium-Rothko Comparison
- [x] Distinguish private-repo 401 from network failure and use the WSL SSH key.
- [x] Route the clone through the Windows proxy with a user-level relay, no config change.
- [x] Clone main plus a sparse partial uefi/rothko tree without overwriting local sources.
- [x] Extract the upstream runtime claim and its pstore logging design.
- [x] Determine lineage: upstream rothkoPkg has no RothkoDisplay/Watchdog drivers.
- [x] Persist the comparison report and record what it changes about prior conclusions.
- **Status:** complete; upstream reaches DXE Core, local stops at shim entry.

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use a task-specific plan inside the K70U workspace | Avoid overwriting the parent's yunluo plans. |
| Create the plan with apply_patch rather than run init-session.ps1 | The installed initializer includes Remove-Item branches; deletion is forbidden. |
| Separate stock MTK LK and the alternate boot-layer LK | The user explicitly says these are different bootloaders. |
| Treat Android14/16 as compatible, while identifying each evidence input | The user explicitly clarified compatibility; version difference is not a claimed failure cause. |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| No connected REA tools in this tool list | 1 | Use the existing documented CLI; do not enable the large MCP catalog. |
| Existing ext4 Mu build tree has no Git metadata | 1 | Preserve it as an identified source snapshot; create a fresh candidate history instead of pretending it has upstream history. |
| First build used an ext4 snapshot predating the Windows overlay edits | 1 | Backed up the old source files, synchronized the overlay, created a fresh build2 snapshot, and rebuilt without deleting the old tree. |
| Reusing a tree with an existing Build directory was rejected by the build wrapper | 1 | Created a new source snapshot with Build excluded and built there. |
| AVBf verifier fed the full 64 MiB partition to gzip | 1 | Bound decompression to Android header `kernel_size`; body and AVBf now both pass. |
| IDA convert_number endpoint refused connection (WinError 10061) | 1 | Do not retry or enable tools; retain hexadecimal values and use saved source/log evidence. No live IDA is needed for this text audit. |
| Initial combined recovery output was truncated | 1 | Read the selected plan/findings/progress in bounded pages; do not treat previews as complete evidence. |
| Existing clang 18 lacks host ASan runtime archives | 1 | Preserve compile log; host-test worker switches to installed GCC sanitizer runtime, without installing tools. |
| KernelSU expands LF to CRLF even with adb shell -T | 1 | Preserve the 134267885-byte transport. A bounded reversal yields 134217728 bytes and exactly matches the complete device before-hash; post-hash is an additional, separately reported check. |
| Device disconnected before optional post-capture hash | 1 | Preserve the verified-before snapshot; record after-hash as unavailable, never claim three-way stability. No reconnection or reboot was issued. |
| REA PE analysis reports IDA provider not configured | 1 | Preserve diagnostics; use existing offline IDALIB/Hex-Rays without enabling MCP or installing tools. |
| Guessed MemoryInitPeiLib.c / MemoryMapHelperLib.c paths do not exist | 1 | Read actual MemoryInitPei.c / MemoryMapHelper.c named in the known snapshot. |
| IDA auto-import attempts missing PDB/Lumina lookups | 1 | No external symbols/results used; reuse the private database and restrict later analysis to local symbols/configuration. |
| Initial LK callee helper mishandled signed immediates | 1 | Retain and label 01 invalid; use corrected 02 only, with targets checked against ELF PT_LOAD bounds. |
| Initial LZMA corruption fixture selected a decoder GUID inside SEC | 1 | Retain failed fixture result; target the parsed GUID-defined section, then run corrected 8/8 tests. |


### Phase 6: Failure Fastboot Branch Attribution
- [x] Align full failed expdb against normal `/proc/pl_lk` sequence.
- [x] Correct handoff reports to distinguish shared wait from the missing ready event.
- [x] Determine whether LK's home-key branch is before boot image parsing and identify its hardware callback semantics.
- [ ] Determine the physical/input source of the asserted key state during a controlled no-key reboot.
- **Status:** in_progress; static cause is proven, physical source still needs a controlled device state.


### Phase 7: Third-Party Boot Packaging Review
- [x] Inventory the bounded handoff-stage package and read boot/LK evidence docs.
- [x] Cross-check the claim's logged markers against K70U normal/failed LK evidence.
- [x] Compare package construction decisions against the current K70U v4 candidate.
- **Status:** complete; raw third-party blackbox/expdb is absent, so the L1/L2 runtime claim remains secondary evidence.


### Phase 8: AVBf Container Candidate
- [x] Confirm K70U boot partition size from saved LK partition inventory.
- [x] Port and independently verify the third-party AVB footer helper.
- [x] Generate a preserved 64 MiB AVBf variant from the current K70U body.
- [ ] Device test and top-level vbmeta chain result remain pending user-controlled boot evidence.
- **Status:** offline phase complete; hardware validation pending.


### Phase 9: LK Home-Key Gate (deprioritized by user correction)
- [x] Recover stripped LK string xrefs and disassemble the home-key decision path.
- [x] Preserve the static dry-run only for research.
- [x] Record that expdb ring history cannot bind this segment to the UEFI failure.
- **Status:** closed as non-causal for the current UEFI investigation.


### Phase 10: UEFI Runtime Evidence and Delivery
- [x] Keep corrected UEFI build with GIC/memory/display/watchdog fixes.
- [x] Produce AVBf boot and flags=3 low-check companion.
- [x] Make AVBf the default in an independent reproducible packer.
- [x] Re-evaluate failed package and correct MTK LK x0/DTB handoff in a
  device-specific BootShim; preserve the generic-shim outputs for comparison.
- [x] Repack and verify body and AVBf DTB-fix variants.
- [x] Split the latest device strings pull into its five retained SEC/LK
  records and classify the normal stock control record versus early LK stops.
- [x] Close the offline fault chain from AEE23 to CoreFreePoolI, verify the
  low-pointer guard in the rebuilt DxeCore, and repack a confirmed AVBf image.
- [ ] Obtain same-boot BootShim/UEFI marker or UEFI fault evidence to prove runtime usability.
- **Status:** in_progress; offline package is ready, runtime proof remains open.

The next controlled device test uses exactly one stage-coded normal candidate:
`work/evidence-20261031/boot-rothko-uefi-stage-coded-20261031-avbf.img`.


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
