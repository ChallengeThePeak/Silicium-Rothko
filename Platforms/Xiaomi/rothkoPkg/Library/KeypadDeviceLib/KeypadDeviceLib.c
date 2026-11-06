// SPDX-License-Identifier: BSD-2-Clause-Patent
// Effective DTBO: Up=GPIO196; Power/Down=MT6363 PWRKEY/HOMEKEY.
#include <Uefi.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/IoLib.h>
#include <Library/KeypadDeviceLib.h>
#include <Library/MemoryMapHelperLib.h>
#include <Library/TimerLib.h>

STATIC EFI_MEMORY_REGION_DESCRIPTOR mGpio, mPmif;
STATIC BOOLEAN mPmicReady, mUpDown;
#define KEY_IRQS (BIT0 | BIT1 | BIT3 | BIT4)

STATIC BOOLEAN PmicWait (UINT32 State) {
  for (UINTN Us = 0; Us < 10000; ++Us) {
    if (((MmioRead32 (mPmif.Address + 0x8A8) >> 1) & 7) == State) return TRUE;
    MicroSecondDelay (1);
  }
  return FALSE;
}
STATIC BOOLEAN PmicRead (UINT16 Reg, UINT8 *Value) {
  if (!PmicWait (0)) return FALSE;
  MmioWrite32 (mPmif.Address + 0x880, (3U << 30) | (4U << 24) | Reg);
  if (!PmicWait (6)) return FALSE;
  *Value = (UINT8)MmioRead32 (mPmif.Address + 0x894);
  MmioWrite32 (mPmif.Address + 0x8A4, 1);
  return TRUE;
}
STATIC BOOLEAN PmicWrite (UINT16 Reg, UINT8 Value) {
  if (!PmicWait (0)) return FALSE;
  MmioWrite32 (mPmif.Address + 0x884, Value);
  MmioWrite32 (mPmif.Address + 0x880, (3U << 30) | BIT29 | (4U << 24) | Reg);
  return PmicWait (0);
}
STATIC VOID PushKey (KEYPAD_RETURN_API *Api, UINT16 Scan, CHAR16 Unicode) {
  EFI_KEY_DATA Key;
  ZeroMem (&Key, sizeof (Key));
  Key.Key.ScanCode = Scan;
  Key.Key.UnicodeChar = Unicode;
  Api->PushEfikeyBufTail (Api, &Key);
  DEBUG ((DEBUG_ERROR, "K70U-UEFI-KEY14: scan=%x char=%x\n", Scan, Unicode));
}
RETURN_STATUS EFIAPI KeypadDeviceConstructor (VOID) {
  EFI_STATUS Status;
  UINT8 Value;
  Status = LocateMemoryRegionByName ("Pinctrl", &mGpio);
  if (EFI_ERROR (Status)) return RETURN_NOT_FOUND;
  Status = LocateMemoryRegionByName ("PMIF", &mPmif);
  if (!EFI_ERROR (Status) && PmicRead (0x90F, &Value)) {
    mPmicReady = PmicWrite (0x90F, Value | KEY_IRQS);
    if (PmicRead (0x91B, &Value)) PmicWrite (0x91B, Value & KEY_IRQS);
  }
  DEBUG ((DEBUG_ERROR, "K70U-UEFI-KEY14: GPIO196 DIN=0x260, PMIF-M SID4 ready=%u\n", mPmicReady));
  return RETURN_SUCCESS;
}
EFI_STATUS EFIAPI KeypadDeviceReset (KEYPAD_DEVICE_PROTOCOL *This) {
  UINT8 Value;
  mUpDown = FALSE;
  if (mPmicReady && PmicRead (0x91B, &Value)) PmicWrite (0x91B, Value & KEY_IRQS);
  return EFI_SUCCESS;
}
EFI_STATUS KeypadDeviceGetKeys (KEYPAD_DEVICE_PROTOCOL *This, KEYPAD_RETURN_API *Api, UINT64 Delta) {
  BOOLEAN Up = (MmioRead32 (mGpio.Address + 0x260) & BIT4) == 0;
  UINT8 Status;
  if (Up && !mUpDown) PushKey (Api, SCAN_UP, CHAR_NULL);
  mUpDown = Up;
  if (mPmicReady && PmicRead (0x91B, &Status)) {
    // Edge latches retain a complete short tap between timer callbacks.
    if (Status & BIT0) PushKey (Api, SCAN_NULL, CHAR_CARRIAGE_RETURN);
    if (Status & BIT1) PushKey (Api, SCAN_DOWN, CHAR_NULL);
    if (Status & KEY_IRQS) PmicWrite (0x91B, Status & KEY_IRQS);
  }
  return EFI_SUCCESS;
}
