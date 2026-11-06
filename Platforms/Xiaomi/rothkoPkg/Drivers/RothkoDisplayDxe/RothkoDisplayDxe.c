#include <Library/RothkoStage.h>
/** @file
  MT6989 (rothko, Redmi K70 Ultra) display bring-up: inherit LK's scanout and
  push command-mode frames, following the approach validated on dali (MT6991).

  The stock LK brings the panel up in DSI command mode (n12_42_02_0a, DSC,
  1220x2712) and leaves the OVL -> DSC -> DSI -> MUTEX chain programmed, with
  the GRAM holding the last logo frame. This driver does NOT rebuild that
  chain. It:

    1. Takes the framebuffer base/size from the live device tree LK handed
       over in x0 (SEC saved it into gSiliciumEntryArgHobGuid).
    2. Probes the OVL blocks LK is actually scanning from, reading back the
       real layer address, pitch and colour format instead of assuming them.
    3. Installs a GOP over the validated layer and mirrors every other active
       full-size layer so a stale overlay cannot cover new text.
    4. On a dirty frame: clean to PoC, arm the inherited mutex group(s), then
       pulse DSI_START 0 -> 1 (vendor mtk_dsi_config_trigger).
    5. Never writes DSC, MMSYS bypass or crossbar registers: those are LK's
       configuration and are trusted as-is.

  Every step is read-mostly and failure is reported through DEBUG only, so a
  wrong register guess degrades to "no update" instead of a hung display.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Uefi.h>

#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/CacheMaintenanceLib.h>
#include <Library/DebugLib.h>
#include <Library/FdtLib.h>
#include <Library/FrameBufferBltLib.h>
#include <Library/HobLib.h>
#include <Library/IoLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/MemoryMapHelperLib.h>
#include <Library/FrameBufferHandoff.h>
#include <Library/PcdLib.h>
#include <Library/UefiBootServicesTableLib.h>

#include <Protocol/GraphicsOutput.h>

#include <Configuration/BootDevices.h>
#include "RothkoDisplayBounds.h"

//
// Bring-up heartbeat.
//
// ROTHKO_HEARTBEAT_MODE = 1: touch no display register, allocate nothing, arm
// no timer -- just PSCI SYSTEM_RESET as soon as DXE dispatches this driver.
// Used to prove DXE is reached at all.
//
// ROTHKO_HEARTBEAT_MODE = 0: real display driver.
//
// ROTHKO_LIVENESS_SECONDS: when non-zero, a timer armed on entry (before any
// display MMIO) issues PSCI SYSTEM_RESET after that many seconds. This makes a
// single boot report three distinguishable outcomes:
//
//   screen shows text, reset at ~15 s  -> SEC, DXE and the display path all work
//   screen stays at the LK logo,
//     reset at ~15 s                   -> SEC + DXE work, display path failed
//   reset at ~33 s (RGU watchdog)      -> SEC never handed off to DXE
//
// The USB/RGU watchdog on this platform fires at roughly 33 s, so 15 s is
// unambiguous.
//
#define ROTHKO_HEARTBEAT_MODE    0
#define ROTHKO_LIVENESS_SECONDS  0

//
// Failure markers.
//
// There is no serial port and the panel may not be updated yet, so the only
// way to learn where this driver gave up is the ATF watchdog dump in expdb:
// it records PC. Each failure branch therefore parks on its own `b .`, at a
// distinct address, and the code below maps PC back to the stage.
//
// Codes (recorded in the DEBUG console and, when the watchdog still fires,
// as PC inside this driver's image):
//   1  device tree / SEC entry HOB unusable
//   2  GOP installation failed
//   3  no validated scanout layer found in the inherited OVL
//   4  no single-mode DSI0 mutex group found
//   5  refresh timer could not be created or armed
//
// ROTHKO_HALT no longer parks the CPU. The ATF watchdog dump only appears for
// the AP RGU path; a PMIC full reset (the kind a dead-loop actually causes on
// this platform) leaves no dump at all, so the old `b .` only bought a 15 s
// reboot and erased the evidence. Log the stage and carry on: GOP is still
// installed, the console still works, and a later frame push can succeed.
//
#define ROTHKO_HALT(code)                                            \
  do {                                                               \
    DEBUG ((DEBUG_ERROR, "ROTHKO: HALT code %u (continuing)\n",       \
      (UINT32)(code)));                                               \
  } while (0)

#include <Library/ArmSmcLib.h>

//
// Watchdog service is provided by RothkoWatchdogDxe before this driver.
// The bisect switch skips display MMIO/GOP without affecting that service.
//
#define ROTHKO_BISECT_NO_MMIO  0

//
// Panel geometry. Visible size is fixed by the panel; the scanout pitch is
// NOT: it is read back from the OVL layer LK programmed.
//
#define PANEL_WIDTH   1220U
#define PANEL_HEIGHT  2712U

//
// Physical address ranges probed for an active scanout (stock vendor DTB).
//   OVLSYS  : disp-ovl0/1/2-2l@14402000/3000/4000
//   OVLSYS1 : disp1-ovl0/1/2-2l@14602000/3000/4000
//
#define OVL_OVLSYS0_BASE   0x14402000U
#define OVL_OVLSYS1_BASE   0x14602000U
#define OVL_UNIT_STRIDE    0x00001000U
#define OVL_UNIT_COUNT     3U

//
// OVL registers (vendor mtk_disp_ovl.c, offsets independent of the SoC).
//
#define OVL_EN             0x00CU
#define OVL_ROI_SIZE       0x020U
#define OVL_DATAPATH_CON   0x024U
#define OVL_SRC_CON        0x02CU
#define OVL_LAYER_STRIDE   0x020U
#define OVL_CON(n)         (0x030U + OVL_LAYER_STRIDE * (n))
#define OVL_SRC_SIZE(n)    (0x038U + OVL_LAYER_STRIDE * (n))
#define OVL_OFFSET(n)      (0x03CU + OVL_LAYER_STRIDE * (n))
#define OVL_PITCH_MSB(n)   (0x040U + OVL_LAYER_STRIDE * (n))
#define OVL_PITCH(n)       (0x044U + OVL_LAYER_STRIDE * (n))
#define OVL_CLIP(n)        (0x04CU + OVL_LAYER_STRIDE * (n))
#define OVL_RDMA_CTRL(n)   (0x0C0U + OVL_LAYER_STRIDE * (n))
#define OVL_CLRFMT_EXT     0x2D0U
#define OVL_DATAPATH_EXT   0x324U
#define OVL_ADDR_BASE      0x0F40U
#define OVL_ADDR(n)        (OVL_ADDR_BASE + OVL_LAYER_STRIDE * (n))
#define OVL_ADDR_MSB(n)    (0x0F4CU + OVL_LAYER_STRIDE * (n))

//
// Layer control fields (mtk_disp_ovl.c L_CON_FLD_*).
//
#define L_CON_CFMT_MASK    (0xFU << 12)
#define L_CON_CFMT_RGB     (1U << 12)
#define L_CON_CFMT_RGBA    (2U << 12)
#define L_CON_CFMT_ARGB    (3U << 12)
#define L_CON_BTSW         BIT24
#define L_CON_RGB_SWAP     BIT25
#define L_CON_CLRFMT_MAN   BIT23

#define OVL_MAX_LAYER      2U

//
// MUTEX registers. MT6989 reuses the MT6983 layout: MOD0 at 0x30, SOF at 0x2C
// (vendor mtk_drm_ddp.c mt6989_ddp_driver_data).
//
#define MUTEX_EN(n)        (0x20U + 0x20U * (n))
#define MUTEX_SOF(n)       (0x2CU + 0x20U * (n))
#define MUTEX_MOD(n)       (0x30U + 0x20U * (n))
#define MUTEX_MOD2(n)      (0x34U + 0x20U * (n))
#define MUTEX_ID_COUNT     10U
#define MUTEX_SOF_MASK     0x7U

//
// MUTEX module bit that selects DSI0. On the side (DISPSYS1) mutex it is
// MOD0[15]; the OVLSYS main mutex carries the overlay/relay chain instead.
//
#define MT6989_MUTEX1_MOD0_DSI0   BIT15

//
// DSI registers (vendor mtk_dsi.c; MT6989 reg_cmdq0_ofs = 0xD00).
//
#define DSI0_BASE          0x1420A000U
#define DSI_START          0x000U
#define DSI_MODE_CTRL      0x014U   // vendor mtk_dsi.c: DSI_MODE_CTRL 0x14
#define DSI_INTSTA         0x00CU
#define DSI_CMD_TYPE1_HS   0x06CU
#define DSI_CMDQ_SIZE      0x060U
#define DSI_CMD0           0xD00U
#define DSI_BUSY           BIT31
#define DSI_CMDQ_SIZE_MAX  0xFFU
#define DSI_CMDQ_SIZE_SEL  BIT15
#define DSI_CMD_HS_HFP_EN  BIT16
#define DSI_WRITE_MEM_START_CMD  0x002C3909U

//
// Only the four reg tuples in the standard mt6989-disp-mutex node.
//
STATIC CONST UINT32  mMutexBanks[] = {
  0x14001000U,  // disp-mutex0@14001000
  0x14201000U,  // disp1-mutex0@14201000 (side)
  0x14401000U,  // disp-mutex0@14401000 (OVLSYS0)
  0x14601000U   // disp-mutex0@14601000 (OVLSYS1)
};

STATIC EFI_GRAPHICS_OUTPUT_MODE_INFORMATION  mInfo;
STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE     mMode;
STATIC FRAME_BUFFER_CONFIGURE                 *mBlt;
STATIC UINT64                                 mFbBase;
STATIC UINT64                                 mFbSize;

//
// Validated scanout buffers. LK commonly leaves two full-size layers aimed at
// the same content; anything else would cover our text, so every one of them
// is mirrored on each refresh.
//
STATIC UINT64  mScanouts[OVL_MAX_LAYER];
STATIC UINT32  mScanoutPitch[OVL_MAX_LAYER];
STATIC BOOLEAN mScanoutByteSwap[OVL_MAX_LAYER];
STATIC UINTN   mScanoutCount;

STATIC UINTN   mMutexId;
STATIC UINT32  mMutexMask;
STATIC BOOLEAN mRefreshActive;
STATIC BOOLEAN mDirty;
STATIC UINTN   mRefreshCount;
STATIC EFI_EVENT  mRefreshEvent;
STATIC EFI_EVENT  mExitEvent;

/**
  Return the scanout pitch of a layer in BYTES.

  OVL_PITCH holds the line stride in bytes, not pixels: the vendor driver
  programs `pending->pitch` straight from the DRM plane pitch (4992 for the
  1248-pixel stride seen in rothko's mtkfb dump), and dali reads the same
  register back and compares it against width * 4. The MSB field extends it
  past 16 bits (mtk_disp_ovl.c L_PITCH_MSB_FLD_SRC_PITCH_MSB).
**/
STATIC
UINT32
LayerPitchBytes (
  IN UINT32  Base,
  IN UINTN   Layer
  );

STATIC
VOID
DumpOvlUnit (
  IN UINT32  Base
  )
{
  UINT32  Enabled;
  UINT32  SrcCon;
  UINTN   Layer;

  Enabled = MmioRead32 (Base + OVL_EN);
  SrcCon  = MmioRead32 (Base + OVL_SRC_CON);
  DEBUG ((
    DEBUG_WARN,
    "ROTHKO: OVL %08x en=%08x src_con=%08x roi=%08x datapath=%08x\n",
    Base,
    Enabled,
    SrcCon,
    MmioRead32 (Base + OVL_ROI_SIZE),
    MmioRead32 (Base + OVL_DATAPATH_CON)
    ));

  for (Layer = 0; Layer < OVL_MAX_LAYER; Layer++) {
    UINT64  Address;
    UINT32  Con;
    UINT32  Size;

    if ((SrcCon & (1U << Layer)) == 0) {
      continue;
    }

    Con     = MmioRead32 (Base + OVL_CON (Layer));
    Size    = MmioRead32 (Base + OVL_SRC_SIZE (Layer));
    Address = MmioRead32 (Base + OVL_ADDR (Layer));
    Address |= ((UINT64)(MmioRead32 (Base + OVL_ADDR_MSB (Layer)) & 0xFU) << 32);

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: OVL %08x L%u con=%08x size=%08x pitch=%u bytes addr=%lx\n",
      Base,
      Layer,
      Con,
      Size,
      LayerPitchBytes (Base, Layer),
      Address
      ));
  }
}

/**
  Return the scanout pitch of a layer in BYTES.

  OVL_PITCH holds the line stride in bytes, not pixels: the vendor driver
  programs `pending->pitch` straight from the DRM plane pitch (4992 for the
  1248-pixel stride seen in rothko's mtkfb dump), and dali reads the same
  register back and compares it against width * 4. The MSB field extends it
  past 16 bits (mtk_disp_ovl.c L_PITCH_MSB_FLD_SRC_PITCH_MSB).
**/
STATIC
UINT32
LayerPitchBytes (
  IN UINT32  Base,
  IN UINTN   Layer
  )
{
  UINT32  Pitch;
  UINT32  Msb;

  Pitch = MmioRead32 (Base + OVL_PITCH (Layer)) & 0xFFFFU;
  Msb   = MmioRead32 (Base + OVL_PITCH_MSB (Layer)) & 0xFU;

  return (Msb << 16) | Pitch;
}

STATIC
BOOLEAN
LayerIsLinear (
  IN UINT32  Base,
  IN UINTN   Layer
  )
{
  UINT32  Con;
  UINT32  PitchMsb;
  UINT32  Rdma;
  UINT32  Allowed;

  Con      = MmioRead32 (Base + OVL_CON (Layer));
  PitchMsb = MmioRead32 (Base + OVL_PITCH_MSB (Layer));
  Rdma     = MmioRead32 (Base + OVL_RDMA_CTRL (Layer));
  Allowed  = L_CON_CFMT_RGBA | L_CON_BTSW | BIT8 | 0xFFU;

  //
  // [k70u-fix 2026-11-02] This driver was written against dali (MT6991) and has
  // never run on rothko (MT6989): the layer was never in the FD, so the dali
  // register rules were never exercised here.
  //
  // Evidence from the stock rothko kernel (work/mtkfb.txt, mtk_ovl_layer_config):
  //   OVL0_2L idx:0 fmt:0x34324258(XB24) addr:0x3ef000000 con:0x10021ff offset:0x0
  //   mtk_plane_atomic_update en1 pitch4992 fmt:XB24 x0 y0 w1220 h2712
  // i.e. the fullscreen scanout layer is a plain linear RGBA layer with the
  // framebuffer address, 1220x2712 and a 4992-byte (1248 px) stride.
  //
  // Only the checks that actually identify the scanout layer stay hard: the
  // colour format, the source size, and (in CollectScanout) the address, the
  // pitch and the containment in the framebuffer carveout. The remaining bits
  // describe how a *composition* is wired, and their encoding differs between
  // the two SoCs, so they are reported instead of vetoing the layer.
  //
  {
    UINT32  SrcSize;
    UINT32  Offset;
    UINT32  Clip;
    UINT32  DpCon;
    UINT32  DpExt;
    UINT32  ClrFmt;
    UINT32  Soft;

    SrcSize = MmioRead32 (Base + OVL_SRC_SIZE (Layer));
    Offset  = MmioRead32 (Base + OVL_OFFSET (Layer));
    Clip    = MmioRead32 (Base + OVL_CLIP (Layer));
    DpCon   = MmioRead32 (Base + OVL_DATAPATH_CON);
    DpExt   = MmioRead32 (Base + OVL_DATAPATH_EXT);
    ClrFmt  = MmioRead32 (Base + OVL_CLRFMT_EXT);

    Soft = 0;
    if ((Con & ~Allowed) != 0) {
      Soft |= 0x0001;
    }
    if (((Con & BIT8) != 0) && ((Con & 0xFFU) != 0xFFU)) {
      Soft |= 0x0002;
    }
    if ((PitchMsb & (BIT16 | BIT20)) != 0) {
      Soft |= 0x0004;
    }
    if ((Rdma & BIT0) == 0) {
      Soft |= 0x0008;
    }
    if ((Rdma & BIT4) != 0) {
      Soft |= 0x0010;
    }
    if (Offset != 0) {
      Soft |= 0x0020;
    }
    if (Clip != 0) {
      Soft |= 0x0040;
    }
    if ((DpCon & (1U << (Layer + 4))) != 0) {
      Soft |= 0x0080;
    }
    if ((DpExt & 7U) != 0) {
      Soft |= 0x0100;
    }
    if (((ClrFmt >> (Layer * 4)) & 3U) != 0) {
      Soft |= 0x0200;
    }

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: LIN L%u soft=%08x con=%08x pitchmsb=%08x rdma=%08x size=%08x off=%08x clip=%08x dpcon=%08x dpext=%08x clrfmt=%08x\n",
      Layer, Soft, Con, PitchMsb, Rdma, SrcSize, Offset, Clip, DpCon, DpExt, ClrFmt
      ));

    //
    // Hard gates: the layer must be a linear RGBA layer of exactly the panel
    // size. Everything else is reported, not vetoed.
    //
    if ((Con & L_CON_CFMT_MASK) != L_CON_CFMT_RGBA) {
      DEBUG ((DEBUG_WARN, "ROTHKO: LIN L%u reject: colour format\n", Layer));
      return FALSE;
    }

    if (SrcSize != (PANEL_WIDTH | (PANEL_HEIGHT << 16))) {
      DEBUG ((DEBUG_WARN, "ROTHKO: LIN L%u reject: source size\n", Layer));
      return FALSE;
    }
  }

  return TRUE;
}

STATIC
BOOLEAN
CollectScanout (
  IN UINT64  Address,
  IN UINT32  PitchBytes,
  IN UINT32  Con,
  IN UINT32  Size
  )
{
  UINTN  Index;

  if (Address == 0) {
    return FALSE;
  }

  if ((Address < mFbBase) || (Address >= mFbBase + mFbSize)) {
    return FALSE;
  }

  if (Size != (PANEL_WIDTH | (PANEL_HEIGHT << 16))) {
    return FALSE;
  }

  //
  // Only packed 32bpp linear formats are accepted. Anything else is a vendor
  // GPU/composition buffer, not a framebuffer we may scribble on.
  //
  if ((Con & L_CON_CFMT_MASK) != L_CON_CFMT_RGBA)
  {
    return FALSE;
  }

  if ((PitchBytes < PANEL_WIDTH * sizeof (UINT32)) ||
      ((PitchBytes % sizeof (UINT32)) != 0))
  {
    return FALSE;
  }

  if (!RothkoSpanFits (
         mFbBase, mFbSize, Address, (UINT64)PitchBytes * PANEL_HEIGHT))
  {
    return FALSE;
  }

  for (Index = 0; Index < mScanoutCount; Index++) {
    if (mScanouts[Index] == Address) {
      return FALSE;
    }
  }

  if (mScanoutCount >= OVL_MAX_LAYER) {
    return FALSE;
  }

  mScanouts[mScanoutCount]     = Address;
  mScanoutPitch[mScanoutCount] = PitchBytes;
  mScanoutByteSwap[mScanoutCount] = (Con & L_CON_BTSW) != 0;
  mScanoutCount++;
  return TRUE;
}

/**
  Probe the six OVL blocks under OVLSYS0/OVLSYS1 and record every layer that
  scans a full-size RGB buffer out of the LK carveout.
**/
STATIC
UINTN
ProbeScanouts (
  VOID
  )
{
  UINTN   Side;
  UINTN   Unit;
  UINTN   Layer;
  UINT32  Base;
  UINT32  SrcCon;

  for (Side = 0; Side < 2; Side++) {
    for (Unit = 0; Unit < OVL_UNIT_COUNT; Unit++) {
      Base = ((Side == 0) ? OVL_OVLSYS0_BASE : OVL_OVLSYS1_BASE) +
             Unit * OVL_UNIT_STRIDE;
      SrcCon = MmioRead32 (Base + OVL_SRC_CON);
      if (((MmioRead32 (Base + OVL_EN) & BIT0) == 0) ||
          (SrcCon == 0) || ((SrcCon & ~3U) != 0) ||
          (MmioRead32 (Base + OVL_ROI_SIZE) !=
           (PANEL_WIDTH | (PANEL_HEIGHT << 16))))
      {
        continue;
      }

      DumpOvlUnit (Base);
      for (Layer = 0; Layer < OVL_MAX_LAYER; Layer++) {
        UINT64  Address;
        UINT32  Pitch;

        if (((SrcCon & (1U << Layer)) == 0) || !LayerIsLinear (Base, Layer)) {
          continue;
        }

        Address = MmioRead32 (Base + OVL_ADDR (Layer));
        Address |= ((UINT64)(MmioRead32 (Base + OVL_ADDR_MSB (Layer)) & 0xFU) << 32);
        Pitch    = LayerPitchBytes (Base, Layer);

        //
        // [k70u 2026-11-02] L_CON_BTSW deliberately NOT enabled.
        //
        // The Blt alpha post-pass forces the top byte to 0xFF. BTSW reverses the
        // entire 32-bit word, which would move that 0xFF into the red channel
        // (0xFF000000 -> 0x000000FF = red and fully transparent). Red/blue order
        // is irrelevant for the boot menu, which is black/white/grey, so leave
        // the LK setting alone.
        //
        CollectScanout (
          Address,
          Pitch,
          MmioRead32 (Base + OVL_CON (Layer)),
          MmioRead32 (Base + OVL_SRC_SIZE (Layer))
          );
      }
    }
  }

  //
  // Prefer the layer whose address is exactly the canonical framebuffer base.
  // That is the buffer this driver draws into and the one LK is most likely
  // scanning, so its pitch is the pitch the GOP and the text console must use.
  // The dali port makes the same requirement mandatory before it enables GOP;
  // here the other validated layers are still mirrored, so a mismatch degrades
  // to "an extra copy per frame" rather than to a blank screen.
  //
  for (UINTN Index = 0; Index < mScanoutCount; Index++) {
    if (mScanouts[Index] == mFbBase) {
      UINT64  SavedAddress = mScanouts[0];
      UINT32  SavedPitch   = mScanoutPitch[0];
      BOOLEAN SavedSwap   = mScanoutByteSwap[0];

      mScanouts[0]     = mScanouts[Index];
      mScanoutPitch[0] = mScanoutPitch[Index];
      mScanoutByteSwap[0] = mScanoutByteSwap[Index];
      mScanouts[Index]     = SavedAddress;
      mScanoutPitch[Index] = SavedPitch;
      mScanoutByteSwap[Index] = SavedSwap;
      break;
    }
  }

  return mScanoutCount;
}

/**
  Locate the single-mode mutex group that drives DSI0, the same way the vendor
  driver and the dali port do: a sampled MOD0 non-zero with SOF selector 0.
**/
STATIC
EFI_STATUS
ProbeMutex (
  VOID
  )
{
  UINTN     Id;
  UINTN     Bank;
  UINTN     Matches;
  UINT32    Mask;
  BOOLEAN   Single;
  UINT32    Mod[ARRAY_SIZE (mMutexBanks)];
  UINT32    Sof[ARRAY_SIZE (mMutexBanks)];

  Matches = 0;

  for (Id = 0; Id < MUTEX_ID_COUNT; Id++) {
    Mask   = 0;
    Single = TRUE;

    for (Bank = 0; Bank < ARRAY_SIZE (mMutexBanks); Bank++) {
      UINT32  Base;

      Base    = mMutexBanks[Bank] + Id * 0x20U;
      Mod[Bank] = MmioRead32 (Base + MUTEX_MOD (0));
      Sof[Bank] = MmioRead32 (Base + MUTEX_SOF (0));

      if ((Mod[Bank] == 0) && (MmioRead32 (Base + MUTEX_MOD2 (0)) == 0)) {
        continue;
      }

      Mask |= 1U << Bank;
      DEBUG ((
        DEBUG_WARN,
        "ROTHKO: mutex id=%u bank=%u en=%08x sof=%08x mod0=%08x mod2=%08x\n",
        Id,
        Bank,
        MmioRead32 (Base + MUTEX_EN (0)),
        Sof[Bank],
        Mod[Bank],
        MmioRead32 (Base + MUTEX_MOD2 (0))
        ));

      if ((Sof[Bank] & MUTEX_SOF_MASK) != 0) {
        Single = FALSE;
      }
    }

    if ((Mask == 0) || !Single) {
      continue;
    }

    //
    // At least one bank must carry DSI0 in its MOD0 (MT6989
    // MT6989_MUTEX1_MOD0_DISP_DSI0 = BIT15, vendor mtk_drm_ddp.c), and some
    // OVLSYS bank must carry an OVL unit (MOD0 bits 0..3 = OVL0_2L..OVL3_2L).
    // Together those two facts pin the group to the LK pipeline that drives
    // this panel. Scan every bank rather than hard-coding an index.
    //
    {
      BOOLEAN  HasDsi;
      BOOLEAN  HasOvl;

      HasDsi = FALSE;
      HasOvl = FALSE;
      for (Bank = 0; Bank < ARRAY_SIZE (mMutexBanks); Bank++) {
        if ((mMutexBanks[Bank] == 0x14201000U) &&
            ((Mod[Bank] & MT6989_MUTEX1_MOD0_DSI0) != 0))
        {
          HasDsi = TRUE;
        }
        if (((mMutexBanks[Bank] == 0x14401000U) ||
             (mMutexBanks[Bank] == 0x14601000U)) &&
            ((Mod[Bank] & 0x0FU) != 0))
        {
          HasOvl = TRUE;
        }
      }

      if (!HasDsi || !HasOvl) {
        continue;
      }
    }

    mMutexId   = Id;
    mMutexMask = Mask;
    Matches++;
  }

  if (Matches == 0) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: no single-mode DSI0 mutex group found\n"));
    return EFI_NOT_FOUND;
  }

  if (Matches > 1) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: %u mutex groups match, refusing to guess\n", Matches));
    return EFI_UNSUPPORTED;
  }

  DEBUG ((DEBUG_WARN, "ROTHKO: mutex id=%u banks=%x\n", mMutexId, mMutexMask));
  return EFI_SUCCESS;
}

/**
  Submit one command-mode frame.

  Follows the dali (MT6991) port exactly, with the MT6989 register offsets
  confirmed against the vendor tree (OnePlus MT6989 kernel, the only MT6989
  source available for this SoC):

    mutex enable for every bank in the validated group, then
    writel(0, DSI_START); writel(1, DSI_START);   -- vendor mtk_dsi_start()

  The trailing "START = 0" that the vendor's mtk_dsi_config_trigger() emits is
  there for the GCE engine to replay atomically; the CPU path (mtk_dsi_start,
  "both CMD and VDO would use it") writes 0 then 1 and leaves it at 1. The
  command queue is likewise a GCE artefact and is not touched here: dali
  produces a visible screen without it.

  The mutex enable happens in Refresh() immediately before this call.
**/
STATIC
BOOLEAN
PushFrame (
  VOID
  )
{
  //
  // [k70u 2026-11-02] Do NOT gate submission on DSI_BUSY.
  //
  // INTSTA bit31 reads back set right after the second frame on this panel and
  // never clears, so every later frame was dropped at this point: the Boot
  // Manager menu had already been drawn into the frame buffer but never reached
  // the panel, which is why the screen froze on the second pushed frame while
  // the firmware kept running normally.
  //
  // The vendor mtk_dsi_start() writes 0 then 1 unconditionally - that is also
  // what LK does while it displays the boot logo on this very panel - so follow
  // it instead of second-guessing the hardware status bit.
  //

  //
  // Vendor mtk_dsi_start(): 0 -> 1, and leave it at 1.
  //
  MmioWrite32 (DSI0_BASE + DSI_START, 0);
  MemoryFence ();
  MmioWrite32 (DSI0_BASE + DSI_START, 1);
  MemoryFence ();
  return TRUE;
}

STATIC
VOID
EFIAPI
Refresh (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  UINTN   Index;
  UINTN   Bytes;

  if (!mRefreshActive) {
    return;
  }

  //
  // [k70u-fix 2026-11-02] Submit on every tick, not only after a GOP blt.
  // The frame buffer console in FrameBufferSerialPortLib draws the UEFI log
  // straight into the frame buffer, and those writes never go through the
  // GOP, so a dirty-only refresh keeps showing the last pushed frame and the
  // log never reaches the panel. The yunluo reference behaves the same way:
  // the panel keeps being refreshed while the log is written, which is why
  // its early boot shows the text appearing line by line.
  //

  //
  // Mirror the canonical buffer into any other layer LK left scanning, so a
  // stale full-screen overlay cannot cover the new frame. Each destination is
  // one panel frame; the source and destination may use different strides, so
  // copy line by line when they disagree.
  //
  Bytes = PANEL_WIDTH * sizeof (UINT32);

  for (Index = 0; Index < mScanoutCount; Index++) {
    if (mScanouts[Index] == mFbBase) {
      continue;
    }

    if (mScanoutPitch[Index] == mScanoutPitch[0]) {
      CopyMem (
        (VOID *)(UINTN)mScanouts[Index],
        (VOID *)(UINTN)mFbBase,
        (UINTN)mScanoutPitch[0] * PANEL_HEIGHT
        );
      WriteBackDataCacheRange (
        (VOID *)(UINTN)mScanouts[Index],
        (UINTN)mScanoutPitch[0] * PANEL_HEIGHT
        );
    } else {
      UINTN  Row;

      for (Row = 0; Row < PANEL_HEIGHT; Row++) {
        CopyMem (
          (VOID *)(UINTN)(mScanouts[Index] + Row * mScanoutPitch[Index]),
          (VOID *)(UINTN)(mFbBase + Row * mScanoutPitch[0]),
          Bytes
          );
      }
      WriteBackDataCacheRange (
        (VOID *)(UINTN)mScanouts[Index],
        (UINTN)mScanoutPitch[Index] * PANEL_HEIGHT
        );
    }
  }

  MemoryFence ();

  //
  // Arm the inherited mutex groups, then run the panel.
  //
  for (Index = 0; Index < ARRAY_SIZE (mMutexBanks); Index++) {
    if ((mMutexMask & (1U << Index)) != 0) {
      MmioWrite32 (mMutexBanks[Index] + MUTEX_EN (mMutexId), 1);
    }
  }

  if (!PushFrame ()) {
    return;
  }

  //
  // [k70u 2026-11-02] Every 25 ticks (5 s) report that frames are still going
  // out, plus the DSI status. Without this the log goes silent after
  // "refresh enabled" and a stalled push looks identical to a working one.
  //
  mRefreshCount++;
  //
  // [k70u 2026-11-04] The 5 s "refresh N frames" heartbeat is gone: bring-up is
  // finished and the line only adds noise to a log that is now read on screen.
  //

  mDirty = FALSE;
  mRefreshCount++;

  if (mRefreshCount <= 2) {
    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: frame %u submitted, dsi status=%08x\n",
      mRefreshCount,
      MmioRead32 (DSI0_BASE + DSI_INTSTA)
      ));
  }
}

STATIC
VOID
EFIAPI
StopRefresh (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  mRefreshActive = FALSE;
}

STATIC
EFI_STATUS
EFIAPI
QueryMode (
  IN  EFI_GRAPHICS_OUTPUT_PROTOCOL          *This,
  IN  UINT32                                ModeNumber,
  OUT UINTN                                 *SizeOfInfo,
  OUT EFI_GRAPHICS_OUTPUT_MODE_INFORMATION  **Info
  )
{
  if ((This == NULL) || (SizeOfInfo == NULL) || (Info == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  *Info       = NULL;
  *SizeOfInfo = 0;
  if (ModeNumber != 0) {
    return EFI_UNSUPPORTED;
  }

  *Info = AllocateCopyPool (sizeof (mInfo), &mInfo);
  if (*Info == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  *SizeOfInfo = sizeof (mInfo);
  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
EFIAPI
SetMode (
  IN EFI_GRAPHICS_OUTPUT_PROTOCOL  *This,
  IN UINT32                        ModeNumber
  )
{
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL  Black;

  if (This == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  if (ModeNumber != 0) {
    return EFI_UNSUPPORTED;
  }

  ZeroMem (&Black, sizeof (Black));
  return This->Blt (
                 This,
                 &Black,
                 EfiBltVideoFill,
                 0, 0, 0, 0,
                 PANEL_WIDTH,
                 PANEL_HEIGHT,
                 0
                 );
}

STATIC
EFI_STATUS
EFIAPI
Blt (
  IN EFI_GRAPHICS_OUTPUT_PROTOCOL       *This,
  IN EFI_GRAPHICS_OUTPUT_BLT_PIXEL      *Buffer,
  IN EFI_GRAPHICS_OUTPUT_BLT_OPERATION  BltOperation,
  IN UINTN                              SourceX,
  IN UINTN                              SourceY,
  IN UINTN                              DestinationX,
  IN UINTN                              DestinationY,
  IN UINTN                              Width,
  IN UINTN                              Height,
  IN UINTN                              Delta
  )
{
  EFI_STATUS  Status;
  EFI_TPL     Tpl;
  UINTN       Pitch;
  UINT64      Start;
  UINT64      End;

  if ((This == NULL) || (mBlt == NULL)) {
    return EFI_NOT_READY;
  }

  switch (BltOperation) {
    case EfiBltVideoToBltBuffer:
      if (!RothkoRectFits (SourceX, SourceY, Width, Height, PANEL_WIDTH, PANEL_HEIGHT)) {
        return EFI_INVALID_PARAMETER;
      }
      break;
    case EfiBltVideoToVideo:
      if (!RothkoRectFits (SourceX, SourceY, Width, Height, PANEL_WIDTH, PANEL_HEIGHT)) {
        return EFI_INVALID_PARAMETER;
      }
      // Fall through: both video rectangles must be valid.
    case EfiBltVideoFill:
    case EfiBltBufferToVideo:
      if (!RothkoRectFits (DestinationX, DestinationY, Width, Height, PANEL_WIDTH, PANEL_HEIGHT)) {
        return EFI_INVALID_PARAMETER;
      }
      break;
    default:
      return EFI_INVALID_PARAMETER;
  }

  Tpl    = gBS->RaiseTPL (TPL_NOTIFY);
  Status = FrameBufferBlt (
             mBlt,
             Buffer,
             BltOperation,
             SourceX,
             SourceY,
             DestinationX,
             DestinationY,
             Width,
             Height,
             Delta
             );

  //
  // [k70u-fix 2026-11-02] GOP has no alpha contract, but LK's inherited overlay
  // is an RGBA blend: a zero reserved byte is fully transparent and whatever LK
  // left in the frame buffer shows through instead of the console text. Force
  // the scanout opaque, the same way the yunluo reference does.
  //
  if (!EFI_ERROR (Status) && (BltOperation != EfiBltVideoToBltBuffer) &&
      (Width != 0) && (Height != 0))
  {
    UINTN   Row;
    UINTN   Col;
    UINT32  *Pixels;

    for (Row = 0; Row < Height; Row++) {
      //
      // [k70u 2026-11-02] FrameBufferBase is a byte address and Pixels is a
      // UINT32*, so both the row stride and the column offset must be scaled by
      // sizeof (UINT32). Without that the whole pass lands at a quarter of the
      // intended height and scribbles over the upper part of the panel - which
      // is exactly the broken coloured strip seen at the top of the screen.
      //
      Pixels = (UINT32 *)(VOID *)(UINTN)(mMode.FrameBufferBase +
               (UINT64)(DestinationY + Row) * mInfo.PixelsPerScanLine * sizeof (UINT32) +
               (UINT64)DestinationX * sizeof (UINT32));

      for (Col = 0; Col < Width; Col++) {
        Pixels[Col] |= 0xFF000000U;
      }
    }
  }

  if (!EFI_ERROR (Status) && (BltOperation != EfiBltVideoToBltBuffer) &&
      (Width != 0) && (Height != 0))
  {
    Pitch = (UINTN)mInfo.PixelsPerScanLine * sizeof (UINT32);
    Start = mMode.FrameBufferBase +
            (UINT64)DestinationY * Pitch +
            (UINT64)DestinationX * sizeof (UINT32);
    End   = Start + (UINT64)(Height - 1) * Pitch +
            (UINT64)Width * sizeof (UINT32);

    //
    // Cache maintenance on a window that leaves the carveout raises a data
    // abort, which only surfaces ~33 s later as a watchdog reset with no way
    // back. Answer a bogus rectangle with an error instead of with a dead
    // machine; FrameBufferBlt has already clipped the pixels that matter.
    //
    if (End > mMode.FrameBufferBase + mMode.FrameBufferSize) {
      gBS->RestoreTPL (Tpl);
      return EFI_INVALID_PARAMETER;
    }

    WriteBackDataCacheRange ((VOID *)(UINTN)Start, (UINTN)(End - Start));
    MemoryFence ();
    mDirty = TRUE;
  }

  gBS->RestoreTPL (Tpl);
  return Status;
}

STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL  mGop = {
  QueryMode,
  SetMode,
  Blt,
  &mMode
};

/**
  Read the framebuffer base/size and the panel name out of the live device
  tree LK passed in x0.

  The blob is validated (magic, fb_base inside RAM) before anything is mapped
  or written: a wrong base would otherwise scribble over live DRAM.
**/
STATIC
EFI_STATUS
ReadDeviceTree (
  VOID
  )
{
  VOID          *Hob;
  UINT64        Dtb;
  CONST UINT32  *Prop;
  INT32         Length;
  INT32         Chosen;
  UINT32        TotalSize;
  EFI_MEMORY_REGION_DESCRIPTOR  DtbRegion;

  Hob = GetFirstGuidHob (&gSiliciumEntryArgHobGuid);
  if (Hob == NULL) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: no SEC entry HOB; x0 was not passed through\n"));
    return EFI_NOT_FOUND;
  }

  if (GET_GUID_HOB_DATA_SIZE (Hob) < sizeof (Dtb)) {
    return EFI_INVALID_PARAMETER;
  }

  Dtb = *(UINT64 *)GET_GUID_HOB_DATA (Hob);
  if ((Dtb == 0) || ((Dtb & 0x3) != 0)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: bogus device tree pointer %lx\n", Dtb));
    return EFI_INVALID_PARAMETER;
  }

  if (EFI_ERROR (LocateMemoryRegionByName ("LK DTB", &DtbRegion)) ||
      !RothkoSpanFits (DtbRegion.Address, DtbRegion.Length, Dtb, 40))
  {
    return EFI_INVALID_PARAMETER;
  }

  TotalSize = Fdt32ToCpu (ReadUnaligned32 ((UINT32 *)(UINTN)(Dtb + 4)));
  if ((TotalSize < 40) ||
      !RothkoSpanFits (DtbRegion.Address, DtbRegion.Length, Dtb, TotalSize))
  {
    return EFI_INVALID_PARAMETER;
  }

  if (FdtCheckHeader ((VOID *)(UINTN)Dtb) != 0) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: x0 %lx is not a device tree\n", Dtb));
    return EFI_INVALID_PARAMETER;
  }

  DEBUG ((DEBUG_WARN, "ROTHKO: device tree at %lx\n", Dtb));

  Chosen = FdtPathOffset ((VOID *)(UINTN)Dtb, "/chosen");
  if (Chosen < 0) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: /chosen missing from the live device tree\n"));
    return EFI_NOT_FOUND;
  }

  //
  // atag,videolfb-fb_base_l / _h / vramSize, all 32-bit cells.
  //
  Prop = FdtGetProp ((VOID *)(UINTN)Dtb, Chosen, "atag,videolfb-fb_base_l", &Length);
  if ((Prop == NULL) || (Length != sizeof (UINT32))) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: no atag,videolfb-fb_base_l in /chosen\n"));
    return EFI_NOT_FOUND;
  }

  mFbBase = Fdt32ToCpu (*Prop);

  Prop = FdtGetProp ((VOID *)(UINTN)Dtb, Chosen, "atag,videolfb-fb_base_h", &Length);
  if ((Prop != NULL) && (Length == sizeof (UINT32))) {
    mFbBase |= ((UINT64)Fdt32ToCpu (*Prop) << 32);
  }

  Prop = FdtGetProp ((VOID *)(UINTN)Dtb, Chosen, "atag,videolfb-vramSize", &Length);
  if ((Prop == NULL) || (Length != sizeof (UINT32))) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: no atag,videolfb-vramSize in /chosen\n"));
    return EFI_NOT_FOUND;
  }

  mFbSize = Fdt32ToCpu (*Prop);

  DEBUG ((DEBUG_WARN, "ROTHKO: LK framebuffer %lx size %lx\n", mFbBase, mFbSize));

  //
  // Sane bounds: below the 4 GiB boundary the UEFI MMU covers, at least one
  // full panel frame, and page aligned.
  //
  if ((mFbBase < 0x40000000ULL) || (mFbBase >= SIZE_4GB) ||
      ((mFbBase & 0xFFF) != 0) ||
      (mFbSize < (UINT64)PANEL_WIDTH * PANEL_HEIGHT * sizeof (UINT32)) ||
      (mFbSize > SIZE_4GB - mFbBase))
  {
    DEBUG ((DEBUG_ERROR, "ROTHKO: framebuffer %lx+%lx rejected\n", mFbBase, mFbSize));
    return EFI_INVALID_PARAMETER;
  }

  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
InstallGop (
  IN EFI_HANDLE  ImageHandle
  )
{
  EFI_STATUS  Status;
  UINTN       ConfigSize;
  UINT32      Pitch;
  UINTN       Index;

  mInfo.Version               = 0;
  mInfo.HorizontalResolution  = PANEL_WIDTH;
  mInfo.VerticalResolution    = PANEL_HEIGHT;
  mInfo.PixelFormat           = PixelBlueGreenRedReserved8BitPerColor;
  if (mScanoutCount != 0) {
    mInfo.PixelFormat = mScanoutByteSwap[0] ?
                       PixelRedGreenBlueReserved8BitPerColor :
                       PixelBlueGreenRedReserved8BitPerColor;
    for (Index = 1; Index < mScanoutCount; Index++) {
      if (mScanoutByteSwap[Index] != mScanoutByteSwap[0]) {
        return EFI_UNSUPPORTED;
      }
    }
  }

  //
  // PixelsPerScanLine must be the real scanout pitch, not the visible width.
  // The panel is 1220 wide but the OVL pitch is read back from hardware as a
  // byte stride, so divide it back down to pixels.
  //
  if ((mScanoutCount != 0) && (mScanoutPitch[0] >= PANEL_WIDTH * sizeof (UINT32))) {
    Pitch = mScanoutPitch[0] / sizeof (UINT32);
  } else {
    Pitch = FixedPcdGet32 (PcdFrameBufferStride);
  }

  if (!RothkoSpanFits (
         mFbBase, mFbSize, mFbBase, (UINT64)Pitch * PANEL_HEIGHT * sizeof (UINT32)))
  {
    return EFI_INVALID_PARAMETER;
  }

  mInfo.PixelsPerScanLine = Pitch;

  mMode.MaxMode         = 1;
  mMode.Mode            = 0;
  mMode.Info            = &mInfo;
  mMode.SizeOfInfo      = sizeof (mInfo);
  mMode.FrameBufferBase = mFbBase;
  mMode.FrameBufferSize = (UINTN)Pitch * PANEL_HEIGHT * sizeof (UINT32);

  DEBUG ((
    DEBUG_WARN,
    "ROTHKO: GOP mode %ux%u pitch=%u format=%u size=%lx scanouts=%u\n",
    PANEL_WIDTH,
    PANEL_HEIGHT,
    Pitch,
    mInfo.PixelFormat,
    mMode.FrameBufferSize,
    mScanoutCount
    ));

  ConfigSize = 0;
  Status     = FrameBufferBltConfigure (
                 (VOID *)(UINTN)mFbBase,
                 &mInfo,
                 NULL,
                 &ConfigSize
                 );
  if ((Status != EFI_BUFFER_TOO_SMALL) || (ConfigSize == 0)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: FrameBufferBltConfigure probe failed %r\n", Status));
    return EFI_DEVICE_ERROR;
  }

  mBlt = AllocatePool (ConfigSize);
  if (mBlt == NULL) {
    return EFI_OUT_OF_RESOURCES;
  }

  Status = FrameBufferBltConfigure ((VOID *)(UINTN)mFbBase, &mInfo, mBlt, &ConfigSize);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: FrameBufferBltConfigure failed %r\n", Status));
    FreePool (mBlt);
    mBlt = NULL;
    return Status;
  }

  Status = gBS->InstallMultipleProtocolInterfaces (
                  &ImageHandle,
                  &gEfiDevicePathProtocolGuid,
                  &DisplayDevicePath,
                  &gEfiGraphicsOutputProtocolGuid,
                  &mGop,
                  NULL
                  );
  if (EFI_ERROR (Status)) {
    FreePool (mBlt);
    mBlt = NULL;
  }

  return Status;
}

STATIC
EFI_STATUS
StartRefresh (
  VOID
  )
{
  EFI_STATUS  Status;
  UINTN       Index;
  BOOLEAN     Found;

  if (mScanoutCount == 0) {
    DEBUG ((DEBUG_WARN, "ROTHKO: no validated scanout; frame push disabled\n"));
    ROTHKO_HALT (3);
    return EFI_NOT_FOUND;
  }

  //
  // dali makes this mandatory: the layer that must be driven is the one whose
  // address is exactly the framebuffer this GOP draws into. Driving any other
  // buffer means the console text lands in memory nobody scans.
  //
  Found = FALSE;
  for (Index = 0; Index < mScanoutCount; Index++) {
    if (mScanouts[Index] == mFbBase) {
      Found = TRUE;
      break;
    }
  }

  if (!Found) {
    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: no scanout layer at %lx; frame push disabled\n",
      mFbBase
      ));
    ROTHKO_HALT (3);
    return EFI_NOT_FOUND;
  }

  //
  // dali checks the panel mode before enabling submission: MODE_CTRL & 3 == 0
  // is command mode. MT6989 keeps that field at offset 0x14 (vendor mtk_dsi.c).
  // If LK left video mode on, a command push would never reach the panel.
  //
  // No command-mode register writes in an unverified video-mode pipeline.
  if ((MmioRead32 (DSI0_BASE + DSI_MODE_CTRL) & 3U) != 0) {
    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: DSI0 mode %x is not command mode; command push disabled\n",
      MmioRead32 (DSI0_BASE + DSI_MODE_CTRL)
      ));
    return EFI_UNSUPPORTED;
  }

  Status = ProbeMutex ();
  if (EFI_ERROR (Status)) {
    ROTHKO_HALT (4);
    return Status;
  }

  Status = gBS->CreateEvent (
                  EVT_SIGNAL_EXIT_BOOT_SERVICES,
                  TPL_NOTIFY,
                  StopRefresh,
                  NULL,
                  &mExitEvent
                  );
  if (EFI_ERROR (Status)) {
    return Status;
  }

  Status = gBS->CreateEvent (
                  EVT_TIMER | EVT_NOTIFY_SIGNAL,
                  TPL_CALLBACK,
                  Refresh,
                  NULL,
                  &mRefreshEvent
                  );
  if (EFI_ERROR (Status)) {
    gBS->CloseEvent (mExitEvent);
    return Status;
  }

  // [k70u-fix 2026-11-02] 200 ms: fast enough for the log to appear to
  // scroll, slow enough not to spend the whole boot copying the frame.
  Status = gBS->SetTimer (mRefreshEvent, TimerPeriodic, 200000ULL);
  if (EFI_ERROR (Status)) {
    gBS->CloseEvent (mRefreshEvent);
    gBS->CloseEvent (mExitEvent);
    return Status;
  }

  mRefreshActive = TRUE;
  Refresh (NULL, NULL);
  DEBUG ((DEBUG_WARN, "ROTHKO: refresh enabled\n"));
  return EFI_SUCCESS;
}

#if (ROTHKO_HEARTBEAT_MODE != 0) || (ROTHKO_LIVENESS_SECONDS != 0)
/**
  Reset the SoC through PSCI.

  Used by the heartbeat mode and by the liveness timer. No display register is
  touched, so this works even when the whole display path is broken.

  NOTE: on this device the SMC is accepted but the SoC does not reset (see
  [RGU] SWSYSRST = 0x0 in the ATF dump), so the caller ends up spinning here.
  That is why the normal build has both users compiled out.
**/
STATIC
VOID
PsciReset (
  VOID
  )
{
  ARM_SMC_ARGS  Args;

  ZeroMem (&Args, sizeof (Args));
  Args.Arg0 = 0x84000009U;   // PSCI SYSTEM_RESET
  ArmCallSmc (&Args);

  for ( ; ;) {
    CpuPause ();
  }
}
#endif

#if ROTHKO_LIVENESS_SECONDS != 0
STATIC EFI_EVENT  mLivenessEvent;

STATIC
VOID
EFIAPI
LivenessNotify (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  PsciReset ();
}
#endif

EFI_STATUS
EFIAPI
RothkoDisplayEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;
  EFI_MEMORY_REGION_DESCRIPTOR  FrameBufferRegion;

#if ROTHKO_HEARTBEAT_MODE
  PsciReset ();
  return EFI_SUCCESS;
#endif

  DEBUG ((DEBUG_WARN, "ROTHKO: display driver entry\n"));

#if ROTHKO_BISECT_NO_MMIO
  //
  // Bisect build: nothing below this point runs. If the platform still resets
  // with no display access at all, the reset does not come from the display
  // driver.
  //
  DEBUG ((DEBUG_WARN, "ROTHKO: bisect build, no display MMIO\n"));
  return EFI_SUCCESS;
#endif

#if ROTHKO_LIVENESS_SECONDS != 0
  //
  // Arm the liveness reset before touching any display register: whatever the
  // display path does next, the reset time still reports how far the firmware
  // got.
  //
  Status = gBS->CreateEvent (
                  EVT_TIMER | EVT_NOTIFY_SIGNAL,
                  TPL_CALLBACK,
                  LivenessNotify,
                  NULL,
                  &mLivenessEvent
                  );
  if (!EFI_ERROR (Status)) {
    Status = gBS->SetTimer (
                    mLivenessEvent,
                    TimerRelative,
                    (UINT64)ROTHKO_LIVENESS_SECONDS * 10000000ULL
                    );
  }
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: liveness timer unavailable %r\n", Status));
  } else {
    DEBUG ((DEBUG_WARN, "ROTHKO: liveness reset armed for %u s\n", ROTHKO_LIVENESS_SECONDS));
  }
#endif

  RothkoStage (13);
  Status = ReadDeviceTree ();
  if (EFI_ERROR (Status)) {
    if (Status == EFI_NOT_FOUND) {
      //
      // Fall back to the address observed on the running device. The GOP is
      // still installed so the console can show something, but no frame is
      // pushed until a scanout is validated.
      //
      mFbBase = 0x00000000FD91F000ULL;
      mFbSize = 0x00000000026E0000ULL;
      DEBUG ((DEBUG_WARN, "ROTHKO: using fallback framebuffer %lx\n", mFbBase));
      Status  = EFI_SUCCESS;
    } else {
      ROTHKO_HALT (1);
      return Status;
    }
  }

  Status = LocateMemoryRegionByName ("Display Reserved", &FrameBufferRegion);
  if (EFI_ERROR (Status) ||
      !RothkoSpanFits (FrameBufferRegion.Address, FrameBufferRegion.Length, mFbBase, mFbSize))
  {
    return EFI_INVALID_PARAMETER;
  }

  //
  // Register the carveout with the debug console library before touching it,
  // so DEBUG text has somewhere to go.
  //
  RothkoStage (14);
  ProbeScanouts ();
  DEBUG ((DEBUG_WARN, "ROTHKO: %u validated scanout layer(s)\n", mScanoutCount));

  //
  // [k70u-fix 2026-11-02] Publish the geometry that is really scanned out.
  // The frame buffer console reads this record on every write and otherwise
  // falls back to Width * BPP (4880), while the panel strides 4992 bytes, so
  // every line would drift 28 pixels and the text would come out skewed.
  //
  if (mScanoutCount != 0)
  {
    FB_HANDOFF  *Handoff;

    Handoff = (FB_HANDOFF *)(UINTN)(mFbBase + mFbSize - FB_HANDOFF_OFFSET);
    Handoff->Width      = PANEL_WIDTH;
    Handoff->Height     = PANEL_HEIGHT;
    Handoff->PitchBytes = mScanoutPitch[0];
    Handoff->Base       = mFbBase;
    Handoff->Magic      = FB_HANDOFF_MAGIC;
    MemoryFence ();

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: published framebuffer geometry %ux%u pitch=%u base=%lx\n",
      PANEL_WIDTH, PANEL_HEIGHT, mScanoutPitch[0], mFbBase
      ));

    //
    // [k70u 2026-11-02] Wipe every scanout layer with the pitch the OVL really
    // scans. Everything drawn so far went through PitchBytes = Width * 4
    // (4880) because the handoff record above did not exist yet, and the panel
    // scans mScanoutPitch[0] (4992) - so those rows drifted 112 bytes further
    // left each line and left patches of LK's green boot splash showing between
    // them. Clearing here, now that the true pitch is known, gives the panel a
    // known starting state.
    //
    for (UINTN Layer = 0; Layer < mScanoutCount; Layer++) {
      UINT8 *LayerBase  = (UINT8 *)(UINTN)mScanouts[Layer];
      UINTN  LayerPitch = mScanoutPitch[Layer];

      for (UINTN Row = 0; Row < PANEL_HEIGHT; Row++) {
        SetMem32 (LayerBase + Row * LayerPitch, PANEL_WIDTH * sizeof (UINT32), 0xFF000000U);
      }

      WriteBackDataCacheRange (LayerBase, LayerPitch * PANEL_HEIGHT);
    }

    DEBUG ((
      DEBUG_WARN,
      "ROTHKO: cleared %u scanout layer(s) with the real pitch\n",
      mScanoutCount
      ));
  }

  RothkoStage (15);
  Status = InstallGop (ImageHandle);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "ROTHKO: GOP install failed %r\n", Status));
    ROTHKO_HALT (2);
    return Status;
  }

  //
  // The scanout pitch is also what the text console must step by. It is
  // published through a PCD at build time, so re-check the two agree and say
  // so loudly when they do not.
  //
  if (mInfo.PixelsPerScanLine != FixedPcdGet32 (PcdFrameBufferStride)) {
    DEBUG ((
      DEBUG_ERROR,
      "ROTHKO: hardware pitch %u px differs from PcdFrameBufferStride %u; "
      "the text console will be skewed until the PCD matches\n",
      mInfo.PixelsPerScanLine,
      FixedPcdGet32 (PcdFrameBufferStride)
      ));
  }

  //
  // Paint the whole framebuffer flat and mark it dirty.
  //
  // Refresh() only submits when mDirty is set, and mDirty is otherwise only
  // set by a GOP Blt. With the debug console reduced to errors-only, nothing
  // may ever draw, and then no frame would be pushed at all -- the panel would
  // stay on LK's logo and the display path would look broken when it is not.
  //
  // This fill is the one signal that does not depend on any console: if the
  // panel turns dark blue, the OVL -> DSC -> DSI push works; if it stays at
  // the logo, the push never reaches the panel.
  //
  {
    UINT32  *Row;
    UINTN   Y;
    UINTN   X;
    UINTN   Pitch;

    Pitch = mInfo.PixelsPerScanLine;
    for (Y = 0; Y < PANEL_HEIGHT; Y++) {
      Row = (UINT32 *)(UINTN)(mFbBase + (UINT64)Y * Pitch * sizeof (UINT32));
      for (X = 0; X < PANEL_WIDTH; X++) {
        Row[X] = 0xFF000000U;   // [k70u] opaque black, was 0xFF102030 diagnostic blue
      }
    }

    WriteBackDataCacheRange (
      (VOID *)(UINTN)mFbBase,
      (UINTN)Pitch * PANEL_HEIGHT * sizeof (UINT32)
      );
    mDirty = TRUE;
  }

  RothkoStage (16);
  Status = StartRefresh ();
  if (EFI_ERROR (Status)) {
    //
    // GOP is installed and the framebuffer is filled; the console can still
    // draw. A dead-loop here only feeds the PMIC watchdog a 15 s reset that
    // leaves no dump. Carry on so BDS can run and the screen has a chance.
    //
    DEBUG ((DEBUG_WARN, "ROTHKO: refresh setup failed %r (GOP still usable)\n", Status));
    ROTHKO_HALT (5);
  }

  RothkoStage (17);
  return EFI_SUCCESS;
}
