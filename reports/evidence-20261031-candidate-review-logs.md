# Independent Candidate Review: Logs, Mapping, And Metadata

Date: 2026-10-31 (Asia/Shanghai)
Reviewer: failure_logs, resumed original worker
Status: in_progress
Shared plan: .planning/2026-10-31-k70u-uefi-lk-evidence

## Scope

- Review the new overlay src/uefi-rothko-evidence-20261031 only.
- Validate its contracts against the independently decoded 23 AEE snapshot
  and static DTB, without presenting those as current hardware success.
- Do not edit root's source, shared planning files, or existing images.
- Reuse the preceding failure audit and its AEE extraction; no new expdb scan.
- Findings should identify actionable bugs, contract gaps, and test limits.

## Review Checklist

- [ ] GIC PCDs, memory descriptors, and standard DTB regions agree.
- [ ] Every intentionally accessed MMIO page is mapped without false aliases.
- [ ] Watchdog service is independent of display and has valid scheduling.
- [ ] Heap, FD, stack, DTB, ramdisk, and debug metadata boundaries agree.
- [ ] DTB header reads and arithmetic cannot cross mapped memory.
- [ ] Framebuffer bounds and dirty-frame retention are coherent.
- [ ] Test results and remaining hardware-only risks are recorded.

## Baseline

- Explicitly resolved the original shared plan and read its three files.
- Root's new overlay is a separate Git repository; parent tracked diff scope
  alone does not show its changes.
- Root reports overlay baseline 1f6ff76 and independent ext4 source baseline
  9e130c47dc599d9aae07192e258259e2c2eb0364.
- Root will remove 0x14020000 from mutex probing because the actual DTB
  identifies it as SMI_LARB, not a fifth mutex bank. Confirm final bytes/code
  reflect that removal before accepting the mapping contract.

## Evidence Reused

- reports/evidence-20261031-failure-logs.md.
- work/evidence-20261031/logs/aee-23-validated/manifest.json.
- Valid ATF snapshot proves historical DXE exception plus watchdog expiry;
  it does not prove display, timer events, or BDS completion.
- Standard GICv3 reg regions:
  GICD=0x0C400000+0x40000, GICR=0x0C440000+0x200000.
- Valid SYS_CUR_PLLK mblock window:
  mb_kernel=0x40000000+0x7C80000 and mb_dtb=0x47C80000+0x400000.

## Findings

No final verdict yet. The old fifth-bank entry is still present in the source
snapshot read during this pass; root has already scheduled its removal.

## Source Checks Completed

- MT6989Pkg.dsc.inc:42-43 uses GICD=0x0C400000 and GICR=0x0C440000.
  MemoryMapLib.c:51-52 uses the same bases and exact DTB lengths. PASS.
- MemoryMapLib.c:29-43 retains FD, stack, 28 MiB heap and the adjacent DTB
  reservation, without enlarging the allocator across the AEE/pstore ranges.
- RothkoWatchdogDxe only writes WDT_RESTART at 0x1C00B008 with 0x1971,
  followed by a memory fence. The 1000000 100-ns period is 100 ms.
- APRIORI order is CpuDxe, ArmGicDxe, MetronomeDxe, TimerDxe, then independent
  RothkoWatchdogDxe; display is later. Its INF consumes Timer/CPU protocols.
- Watchdog event runs at TPL_NOTIFY, while display refresh runs at
  TPL_CALLBACK. It does not write MODE/reset-route/NONRST registers.
- ReadDeviceTree first validates the GUID HOB payload length, pointer alignment,
  and a mapped 40-byte DTB header span, then bounds TotalSize before libfdt.
- Source still includes 0x14020000 as `MUTEX AUX` and in mMutexBanks at this
  intermediate read. This is not accepted; final removal is required.
- Reviewed complete RothkoDisplayDxe.c and watchdog source/INF/APRIORI/FDF.
- Scoped new-overlay Git diff confirms six modified tracked files; newly
  added watchdog/helper files are not included in ordinary diff --stat.
  Parent Git --stat alone would miss this separate repository.

## Test Log

- No build, device operation, deletion, or existing-artifact overwrite.
- Git emitted autocrlf warnings on the new overlay. Root's WSL build must use
  the normalized/copied candidate state, not presume NTFS line endings.
