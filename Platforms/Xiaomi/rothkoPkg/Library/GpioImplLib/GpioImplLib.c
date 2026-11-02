/**
  [k70u 2026-11-02] MT6989 GPIO platform description.

  MTK keeps one register layout for the whole GPIO controller generation
  (MT67xx .. MT69xx): direction / data-out / data-in / mode blocks indexed by
  pin number. The MT6789 package uses exactly the same offsets, so only the
  pin count differs: rothko's DT says gpio-ranges = <..., 0xFB> = 251 pins.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Library/GpioImplLib.h>

MTK_GPIO_PLATFORM_INFO gPlatformInfo = {
  .SetOffset     = 0x4,
  .ResetOffset   = 0x8,
  .DirOffset     = 0x0,
  .DataOutOffset = 0x100,
  .DataInOffset  = 0x200,
  .ModeOffset    = 0x300,
  .MaxPin        = 251,
};
