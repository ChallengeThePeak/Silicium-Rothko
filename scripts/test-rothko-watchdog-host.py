#!/usr/bin/env python3
"""Compile the actual watchdog driver against host mocks, without device access.

Run in WSL with an existing source and a new output directory on ext4.
RothkoStage is mocked: its MMIO, hardware IRQ delivery, and timing are not tested.
All generated files are retained. Existing output directories are refused.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys


HEADERS = r"""
#ifndef MOCK_UEFI_H
#define MOCK_UEFI_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#define STATIC static
#define VOID void
#define IN
#define EFIAPI
#define TRUE true
#define FALSE false
#define DEBUG(args) ((void)0)
#define DEBUG_ERROR 1
typedef uint8_t UINT8;
typedef uint32_t UINT32;
typedef uint64_t UINT64;
typedef uintptr_t UINTN;
typedef bool BOOLEAN;
typedef UINT64 EFI_STATUS;
typedef VOID *EFI_EVENT;
typedef VOID *EFI_HANDLE;
typedef struct { UINT32 Dummy; } EFI_SYSTEM_TABLE;
typedef struct { UINT32 Dummy; } EFI_GUID;
typedef VOID (*EFI_EVENT_NOTIFY)(EFI_EVENT, VOID *);
typedef enum { TimerCancel, TimerPeriodic, TimerRelative } EFI_TIMER_DELAY;
#define EFI_SUCCESS 0ULL
#define EFIERR(n) (0x8000000000000000ULL | (n))
#define EFI_NOT_FOUND EFIERR(14)
#define EFI_OUT_OF_RESOURCES EFIERR(9)
#define EFI_DEVICE_ERROR EFIERR(7)
#define EFI_INVALID_PARAMETER EFIERR(2)
#define EFI_ERROR(status) (((status) & 0x8000000000000000ULL) != 0)
#define EVT_TIMER 0x80000000U
#define EVT_NOTIFY_SIGNAL 0x00000200U
#define EVT_SIGNAL_EXIT_BOOT_SERVICES 0x00000201U
#define TPL_NOTIFY 16U
typedef struct {
  EFI_STATUS (*LocateProtocol)(const EFI_GUID *, VOID *, VOID **);
  EFI_STATUS (*CreateEvent)(UINT32, UINTN, EFI_EVENT_NOTIFY, VOID *, EFI_EVENT *);
  EFI_STATUS (*SetTimer)(EFI_EVENT, EFI_TIMER_DELAY, UINT64);
  EFI_STATUS (*CloseEvent)(EFI_EVENT);
} EFI_BOOT_SERVICES;
static EFI_BOOT_SERVICES *gBS;
static EFI_GUID gEfiTimerArchProtocolGuid;
static UINT32 MmioWrite32(UINTN Address, UINT32 Value);
static UINT32 MmioRead32(UINTN Address);
static VOID MemoryFence(VOID);
static VOID RothkoStage(UINT32 Stage);
#endif
"""


HARNESS = r"""
#include <stdio.h>
#include <string.h>
#include "MockUefi.h"
#include @SOURCE@

typedef struct {
  UINT32 Type;
  UINTN Tpl;
  EFI_EVENT_NOTIFY Notify;
  VOID *Context;
} EVENT_RECORD;
static EVENT_RECORD events[2];
static EFI_EVENT closed[2], last_timer;
static unsigned failures, mock_errors, locate_calls, create_calls, close_calls;
static unsigned periodic_calls, cancel_calls, stage_calls, last_stage;
static unsigned fail_create_at;
static bool fail_locate, fail_timer;
static UINT64 writes, fences, bad_writes, sequence, last_write_sequence;
static UINT64 cancel_sequence, last_period;
static const char *test_name;

#define CHECK(expr) do { if (!(expr)) { \
  fprintf(stderr, "FAIL %s:%d: %s\n", test_name, __LINE__, #expr); \
  failures++; \
} } while (0)

static UINT32 MmioWrite32(UINTN Address, UINT32 Value) {
  writes++;
  last_write_sequence = ++sequence;
  if (Address != (UINTN)0x1C00B008U || Value != 0x1971U) bad_writes++;
  return Value;
}
static UINT32 MmioRead32(UINTN Address) { (void)Address; return 0x7dU; }
static VOID MemoryFence(VOID) { fences++; sequence++; }
static VOID RothkoStage(UINT32 Stage) { stage_calls++; last_stage = Stage; }

static EFI_STATUS Locate(const EFI_GUID *Guid, VOID *Registration, VOID **Protocol) {
  locate_calls++;
  CHECK(Guid == &gEfiTimerArchProtocolGuid && Registration == NULL);
  if (fail_locate) return EFI_NOT_FOUND;
  *Protocol = &gEfiTimerArchProtocolGuid;
  return EFI_SUCCESS;
}
static EFI_STATUS Create(UINT32 Type, UINTN Tpl, EFI_EVENT_NOTIFY Notify,
                         VOID *Context, EFI_EVENT *Event) {
  unsigned index = create_calls++;
  if (create_calls == fail_create_at) return EFI_OUT_OF_RESOURCES;
  if (index >= 2 || Event == NULL) { mock_errors++; return EFI_INVALID_PARAMETER; }
  events[index] = (EVENT_RECORD){Type, Tpl, Notify, Context};
  *Event = &events[index];
  return EFI_SUCCESS;
}
static EFI_STATUS SetTimer(EFI_EVENT Event, EFI_TIMER_DELAY Type, UINT64 Period) {
  last_timer = Event;
  last_period = Period;
  if (Type == TimerCancel) {
    cancel_calls++;
    cancel_sequence = ++sequence;
    CHECK(Period == 0);
  } else if (Type == TimerPeriodic) {
    periodic_calls++;
    if (fail_timer) return EFI_DEVICE_ERROR;
  } else { mock_errors++; return EFI_INVALID_PARAMETER; }
  return EFI_SUCCESS;
}
static EFI_STATUS Close(EFI_EVENT Event) {
  if (close_calls >= 2) { mock_errors++; return EFI_INVALID_PARAMETER; }
  closed[close_calls++] = Event;
  CHECK(Event == &events[0] || Event == &events[1]);
  return EFI_SUCCESS;
}
static EFI_BOOT_SERVICES services = {Locate, Create, SetTimer, Close};

static bool Enter(VOID) {
  EFI_STATUS status = RothkoWatchdogEntry(NULL, NULL);
  CHECK(status == EFI_SUCCESS);
  CHECK(mActive && writes == 1);
  CHECK(create_calls == 2 && periodic_calls == 1 && close_calls == 0);
  CHECK(mKickEvent == &events[0] && mExitEvent == &events[1]);
  CHECK(events[0].Type == (EVT_TIMER | EVT_NOTIFY_SIGNAL));
  CHECK(events[1].Type == EVT_SIGNAL_EXIT_BOOT_SERVICES);
  CHECK(events[0].Tpl == TPL_NOTIFY && events[1].Tpl == TPL_NOTIFY);
  CHECK(events[0].Notify == KickWatchdog && events[1].Notify == StopWatchdog);
  CHECK(events[0].Context == NULL && events[1].Context == NULL);
  CHECK(last_timer == mKickEvent && last_period == 1000000ULL);
  return failures == 0;
}
static VOID Callback(VOID) {
  if (events[0].Notify == NULL) { failures++; return; }
  events[0].Notify(mKickEvent, events[0].Context);
}
static VOID Continued(VOID) {
  if (!Enter()) return;
  for (unsigned i = 0; i < 10000; i++) Callback();
  printf("continued_feeding writes=%llu expected=10001\n", (unsigned long long)writes);
  CHECK(writes == 10001);
  CHECK(mActive && cancel_calls == 0);
}
static VOID Inactive(VOID) {
  CHECK(!mActive);
  for (unsigned i = 0; i < 1000; i++) KickWatchdog(NULL, NULL);
  CHECK(writes == 0 && fences == 0);
}
static VOID Stop(VOID) {
  if (!Enter()) return;
  for (unsigned i = 0; i < 3; i++) Callback();
  UINT64 before = writes;
  events[1].Notify(mExitEvent, events[1].Context);
  CHECK(writes == before + 1 && !mActive);
  CHECK(cancel_calls == 1 && last_timer == mKickEvent && last_period == 0);
  CHECK(cancel_sequence > last_write_sequence);
  CHECK(close_calls == 0);
  before = writes;
  for (unsigned i = 0; i < 1000; i++) Callback();
  CHECK(writes == before);
}
static VOID EntryFailure(unsigned step) {
  fail_locate = step == 0;
  fail_create_at = step == 1 ? 1 : step == 2 ? 2 : 0;
  fail_timer = step == 3;
  EFI_STATUS expected = step == 0 ? EFI_NOT_FOUND :
                        step == 3 ? EFI_DEVICE_ERROR : EFI_OUT_OF_RESOURCES;
  CHECK(RothkoWatchdogEntry(NULL, NULL) == expected);
  CHECK(!mActive && locate_calls == 1);
  CHECK(writes == (step == 0 ? 0U : 1U));
  CHECK(create_calls == (step == 0 ? 0U : step == 1 ? 1U : 2U));
  CHECK(periodic_calls == (step == 3 ? 1U : 0U) && cancel_calls == 0);
  CHECK(close_calls == (step == 2 ? 1U : step == 3 ? 2U : 0U));
  if (step == 2) CHECK(closed[0] == &events[0]);
  if (step == 3) CHECK(closed[0] == &events[1] && closed[1] == &events[0]);
  UINT64 before = writes;
  KickWatchdog(NULL, NULL);
  CHECK(writes == before);
}
int main(int argc, char **argv) {
  if (argc != 2) return 2;
  test_name = argv[1];
  gBS = &services;
  if (!strcmp(test_name, "continued_feeding")) Continued();
  else if (!strcmp(test_name, "inactive")) Inactive();
  else if (!strcmp(test_name, "stop")) Stop();
  else if (!strcmp(test_name, "locate_failure")) EntryFailure(0);
  else if (!strcmp(test_name, "create_first_failure")) EntryFailure(1);
  else if (!strcmp(test_name, "create_second_failure")) EntryFailure(2);
  else if (!strcmp(test_name, "timer_failure")) EntryFailure(3);
  else return 2;
  CHECK(mock_errors == 0 && bad_writes == 0 && fences == writes);
  if (strcmp(test_name, "inactive")) CHECK(stage_calls == 1 && last_stage == 12);
  else CHECK(stage_calls == 0);
  printf("%s %s\n", failures ? "FAIL" : "PASS", test_name);
  return failures ? 1 : 0;
}
"""

CASES = (
    "continued_feeding", "inactive", "stop", "locate_failure",
    "create_first_failure", "create_second_failure", "timer_failure",
)


def write_new(path, contents):
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(contents)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--compiler", default=None, help="Existing clang or gcc executable")
    args = parser.parse_args()
    if sys.platform != "linux":
        parser.error("Run this host test in the project's WSL distribution")
    source = args.source.resolve(strict=True)
    if not source.is_file() or any(c in str(source) for c in '\r\n"\\'):
        parser.error("Source must be a regular C file with an includable path")
    output = args.output.absolute()
    if output.exists() or output.is_symlink():
        parser.error("Output already exists; select a new directory")
    parent = output.parent.resolve(strict=True)
    fs_type = subprocess.check_output(["stat", "-f", "-c", "%T", str(parent)], text=True).strip()
    if fs_type not in ("ext2/ext3", "ext4"):
        parser.error("Generated/compiler outputs must stay on ext4, not a Windows mount")
    compiler = (shutil.which(args.compiler) if args.compiler else
                shutil.which("gcc") or shutil.which("clang"))
    if compiler is None:
        parser.error("No existing clang/gcc compiler found")
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    output.mkdir(mode=0o700)
    include = output / "include"
    include.mkdir()
    for name in ("Library", "Protocol"):
        (include / name).mkdir()
    write_new(include / "MockUefi.h", HEADERS)
    stubs = (
        "Uefi.h", "Library/RothkoStage.h", "Library/BaseLib.h",
        "Library/DebugLib.h", "Library/IoLib.h", "Library/UefiBootServicesTableLib.h",
        "Protocol/Cpu.h", "Protocol/Timer.h",
    )
    for name in stubs:
        write_new(include / name, '#include "MockUefi.h"\n')
    harness = output / "watchdog-host.c"
    write_new(harness, HARNESS.replace("@SOURCE@", json.dumps(str(source), ensure_ascii=False)))
    executable = output / "watchdog-host"
    command = [
        compiler, "-std=c11", "-O1", "-g", "-Wall", "-Wextra",
        "-Wno-unused-parameter", "-Wno-unused-function", "-fno-omit-frame-pointer",
        "-fsanitize=address,undefined", "-fno-sanitize-recover=all",
        "-fno-pie", "-no-pie", "-I", str(include), str(harness), "-o", str(executable),
    ]
    with (output / "compile.log").open("x", encoding="utf-8") as stream:
        compile_result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    result = {
        "source": str(source), "source_sha256": source_hash, "command": command,
        "harness_sha256": hashlib.sha256(harness.read_bytes()).hexdigest(),
        "test_script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "compiler": subprocess.check_output([compiler, "--version"], text=True).splitlines()[0],
        "compile_returncode": compile_result.returncode, "tests": [],
        "scope": "Actual driver included; RothkoStage mocked. No hardware/IRQ/timing validation.",
    }
    env = os.environ.copy()
    env["ASAN_OPTIONS"] = "halt_on_error=1:abort_on_error=0:disable_coredump=1:detect_leaks=1"
    env["UBSAN_OPTIONS"] = "halt_on_error=1:print_stacktrace=1"
    if compile_result.returncode == 0:
        # Separate processes reset driver static state without patching its source.
        for name in CASES:
            try:
                run = subprocess.run([str(executable), name], capture_output=True, text=True,
                                     env=env, timeout=15)
                returncode, stdout, stderr = run.returncode, run.stdout, run.stderr
            except subprocess.TimeoutExpired:
                returncode, stdout, stderr = 124, "", "Test timed out after 15 seconds\n"
            write_new(output / (name + ".stdout.txt"), stdout)
            write_new(output / (name + ".stderr.txt"), stderr)
            result["tests"].append({"name": name, "returncode": returncode,
                                    "stdout": stdout, "stderr": stderr})
    result["source_unchanged"] = hashlib.sha256(source.read_bytes()).hexdigest() == source_hash
    result["passed"] = (
        compile_result.returncode == 0 and result["source_unchanged"]
        and len(result["tests"]) == len(CASES)
        and all(test["returncode"] == 0 for test in result["tests"])
    )
    write_new(output / "result.json", json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
