/** @file
  [k70u 2026-11-04] Keep the platform watchdog fed while UEFI is running.

  Nothing petted the MTK watchdog once BDS reached the menus, so a session that
  sat idle was reset after the inherited timeout.  That made the screen useless
  as a diagnostic surface: whatever it showed disappeared on its own.

  The RGU/WDT block is at 0x1C00B000 (stock DTB /watchdog@1c00b000).  Writing
  MTK_WDT_RESTART_KEY (0x1971) to offset 0x08 restarts the timer; the firmware
  does that from a periodic timer event.

  Copyright (c) 2026. SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Uefi.h>

#include <Library/DebugLib.h>
#include <Library/IoLib.h>
#include <Library/UefiBootServicesTableLib.h>

#define ROTHKO_WDT_BASE          0x1C00B000U
#define ROTHKO_WDT_RESTART       0x00000008U
#define ROTHKO_WDT_RESTART_KEY   0x00001971U

//
// 500 ms in 100 ns units.  Short enough that a long menu pause cannot expire,
// long enough that the event costs nothing.
//
#define ROTHKO_WDT_PERIOD        5000000U

//
// [k70u 2026-11-04] Stop feeding after two minutes.  Feeding forever made
// every hang permanent - the watchdog could never fire, so the device had to
// be power cycled by hand and the pstore log died with it.
//
#define ROTHKO_WDT_FEED_TICKS    240U

STATIC EFI_EVENT  mTimerEvent = NULL;
STATIC UINT32     mTick       = 0;

STATIC
VOID
EFIAPI
RothkoWdtTick (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  (VOID)Event;
  (VOID)Context;

  if (mTick >= ROTHKO_WDT_FEED_TICKS) {
    return;
  }

  MmioWrite32 (ROTHKO_WDT_BASE + ROTHKO_WDT_RESTART, ROTHKO_WDT_RESTART_KEY);

  mTick++;
  if (mTick == 20) {
    //
    // One line after ten seconds: proves the feed is alive without flooding
    // the console while somebody reads the screen.
    //
    DEBUG ((DEBUG_ERROR, "ROTHKO-WDT: fed %u times, mode=0x%08x status=0x%08x\n",
            mTick,
            MmioRead32 (ROTHKO_WDT_BASE + 0x00),
            MmioRead32 (ROTHKO_WDT_BASE + 0x0C)));
  }
}

EFI_STATUS
EFIAPI
RothkoWatchdogEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;
  UINT32      Mode;

  (VOID)ImageHandle;
  (VOID)SystemTable;

  Mode = MmioRead32 (ROTHKO_WDT_BASE + 0x00);
  DEBUG ((DEBUG_ERROR,
          "ROTHKO-WDT: base=0x%x mode=0x%08x length=0x%08x status=0x%08x\n",
          ROTHKO_WDT_BASE, Mode,
          MmioRead32 (ROTHKO_WDT_BASE + 0x04),
          MmioRead32 (ROTHKO_WDT_BASE + 0x0C)));

  //
  // Feed once immediately: the inherited timer may already be close to expiry.
  //
  MmioWrite32 (ROTHKO_WDT_BASE + ROTHKO_WDT_RESTART, ROTHKO_WDT_RESTART_KEY);

  Status = gBS->CreateEvent (
                  EVT_TIMER | EVT_NOTIFY_SIGNAL,
                  TPL_CALLBACK,
                  RothkoWdtTick,
                  NULL,
                  &mTimerEvent
                  );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO-WDT: CreateEvent failed %r\n", Status));
    return Status;
  }

  Status = gBS->SetTimer (mTimerEvent, TimerPeriodic, ROTHKO_WDT_PERIOD);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO-WDT: SetTimer failed %r\n", Status));
    gBS->CloseEvent (mTimerEvent);
    mTimerEvent = NULL;
    return Status;
  }

  DEBUG ((DEBUG_ERROR, "ROTHKO-WDT: feeding every %u ms, the device will not self-reset\n",
          ROTHKO_WDT_PERIOD / 10000));
  return EFI_SUCCESS;
}
