#!/usr/bin/env python3
"""
Harden the dual-layout probe and make presses report immediately.

Two problems with the first version:

1. Locking on "register reads 0" is unsafe. If the v2 layout is the real one,
   the legacy candidate 0x200+0x60 = 0x260 falls inside the v2 mode block at an
   offset past the last pin, which reads 0 - so an idle read would have locked
   the WRONG layout. The pull-up gives a much better signal: only the register
   that is really wired to pin 196 can read 1 while the key is up. So:
     - record the idle level of both candidates,
     - if exactly one of them reads 1, lock it immediately,
     - otherwise lock whichever one goes 1 -> 0 on a press.

2. A press was only reported after 500 ms (the repeat threshold) or on release,
   which makes the menu feel dead. Report on the first pressed poll, then repeat.
"""
from pathlib import Path
import sys

P = Path("/home/ubuntu/rothko-upstream-20261102/uefi-full/Platforms/Xiaomi/rothkoPkg/Library/KeypadDeviceLib/KeypadDeviceLib.c")
t = P.read_text(encoding="utf-8")


def sub(old, new, why):
    global t
    if old not in t:
        print(f"ERROR: anchor not found: {why}")
        sys.exit(2)
    t = t.replace(old, new, 1)
    print(f"ok: {why}")


# --- 1. state for the idle levels -------------------------------------------
sub(
    "STATIC INTN                         mLockedLayout = -1;",
    "STATIC INTN                         mLockedLayout = -1;\nSTATIC UINT32                       mIdleLevel[LAYOUT_COUNT];",
    "idle level storage",
)

# --- 2. record idle levels and try an immediate lock ------------------------
sub(
    """  for (Index = 0; Index < LAYOUT_COUNT; Index++) {
    Idle[Index] = MmioRead32 (mPinctrlRegion.Address + mDinOffset[Index] + PIN_WORD (ROTHKO_VOLUME_UP_GPIO));
  }
""",
    """  for (Index = 0; Index < LAYOUT_COUNT; Index++) {
    Idle[Index]        = MmioRead32 (mPinctrlRegion.Address + mDinOffset[Index] + PIN_WORD (ROTHKO_VOLUME_UP_GPIO));
    mIdleLevel[Index]  = (Idle[Index] >> PIN_BIT (ROTHKO_VOLUME_UP_GPIO)) & 1;
  }

  //
  // Only the register that is really connected to pin 196 can read 1 while the
  // key is up, because the pin has an internal pull-up. Any other candidate is
  // either an unrelated block or an unimplemented offset, and reads 0. So a
  // single "1" is already conclusive.
  //
  {
    INTN  Candidate = -1;
    UINTN PulledUp  = 0;

    for (Index = 0; Index < LAYOUT_COUNT; Index++) {
      if (mIdleLevel[Index] == 1) {
        PulledUp++;
        Candidate = (INTN)Index;
      }
    }

    if (PulledUp == 1) {
      mLockedLayout = Candidate;
      DEBUG ((DEBUG_ERROR, "ROTHKO-KEYPAD: locked %a at boot (only register reading high)\\n", mLayoutName[Candidate]));
    }
  }
""",
    "idle-based lock",
)

# --- 3. press-time lock must require a 1 -> 0 transition --------------------
sub(
    """        for (UINTN Candidate = 0; Candidate < LAYOUT_COUNT; Candidate++) {
          if (!ReadPinLevel (Candidate, Context->Pin)) {
            mLockedLayout = (INTN)Candidate;
            DEBUG ((DEBUG_ERROR, "ROTHKO-KEYPAD: locked %a (pin %u read 0)\\n", mLayoutName[Candidate], Context->Pin));
            break;
          }
        }
""",
    """        for (UINTN Candidate = 0; Candidate < LAYOUT_COUNT; Candidate++) {
          //
          // Require a real 1 -> 0 transition, otherwise an unimplemented
          // offset that always reads 0 would win the race.
          //
          if ((mIdleLevel[Candidate] == 1) && !ReadPinLevel (Candidate, Context->Pin)) {
            mLockedLayout = (INTN)Candidate;
            DEBUG ((DEBUG_ERROR, "ROTHKO-KEYPAD: locked %a on press (pin %u went 1 -> 0)\\n", mLayoutName[Candidate], Context->Pin));
            break;
          }
        }
""",
    "press-time lock",
)

# --- 4. report the press immediately ---------------------------------------
sub(
    """    case KEYSTATE_RELEASED:
      if (IsPressed) {
        Context->Time  = 0;
        Context->State = KEYSTATE_PRESSED;
      }

      break;

    case KEYSTATE_PRESSED:
      if (IsPressed) {
        //
        // Report on the first poll of a press, then repeat after 500 ms and
        // every 100 ms while the key stays down, so a short tap is never lost
        // but a held key still walks through the menu.
        //
        if (!Context->Repeat && Context->Time >= MS2NS (500)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time   = 0;
          Context->Repeat = TRUE;
        } else if (Context->Repeat && Context->Time >= MS2NS (100)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time = 0;
        }
      } else {
        if (!Context->Repeat) {
          //
          // Short press: report once on release.
          //
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
        }

        Context->Time   = 0;
        Context->Repeat = FALSE;
        Context->State  = KEYSTATE_RELEASED;
      }

      break;
""",
    """    case KEYSTATE_RELEASED:
      if (IsPressed) {
        //
        // Report the press immediately; waiting for the repeat threshold makes
        // the menu feel unresponsive.
        //
        KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
        Context->Time   = 0;
        Context->Repeat = FALSE;
        Context->State  = KEYSTATE_PRESSED;
      }

      break;

    case KEYSTATE_PRESSED:
      if (IsPressed) {
        //
        // Auto-repeat: first repeat after 500 ms, then every 100 ms.
        //
        if (!Context->Repeat && Context->Time >= MS2NS (500)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time   = 0;
          Context->Repeat = TRUE;
        } else if (Context->Repeat && Context->Time >= MS2NS (100)) {
          KeypadReturnApi->PushEfikeyBufTail (KeypadReturnApi, &Context->KeyData);
          Context->Time = 0;
        }
      } else {
        Context->Time   = 0;
        Context->Repeat = FALSE;
        Context->State  = KEYSTATE_RELEASED;
      }

      break;
""",
    "immediate press report",
)

P.write_text(t, encoding="utf-8")
print("done")
