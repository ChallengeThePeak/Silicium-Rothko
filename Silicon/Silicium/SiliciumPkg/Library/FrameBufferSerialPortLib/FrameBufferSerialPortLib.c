#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/CacheMaintenanceLib.h>
#include <Library/MemoryMapHelperLib.h>
#include <Library/SerialPortLib.h>
#include <Library/TimerLib.h>

#include <Library/FrameBufferHandoff.h>

#include "FrameBuffer.h"
#include "Font.h"

#define PSTORE_BASE       0x48090000
// The pmsg zone is last: mem_size (0xE0000) - pmsg_size (0x80000).
#define PSTORE_PMSG_OFFSET 0x00060000
#define PSTORE_PMSG_SIZE  0x00080000
#define PSTORE_SIGNATURE  0x43474244

typedef struct {
  volatile UINT32  Signature;
  volatile INT32   Start;
  volatile INT32   Size;
  volatile UINT8   Data[];
} PSTORE_BUFFER;

FB_GEOMETRY  mFbGeometry;

STATIC
VOID
PstoreWrite (
  IN CONST UINT8  *Data,
  IN UINTN         Length
  )
{
  PSTORE_BUFFER  *Buffer;
  UINTN           Capacity;
  UINTN           Start;
  UINTN           Count;
  UINTN           FirstPart;

  if (Length == 0) {
    return;
  }

  Buffer   = (PSTORE_BUFFER *)(UINTN)(PSTORE_BASE + PSTORE_PMSG_OFFSET);
  Capacity = PSTORE_PMSG_SIZE - sizeof (*Buffer);

  if ((Buffer->Signature != PSTORE_SIGNATURE) ||
      (Buffer->Size < 0) || ((UINTN)Buffer->Size > Capacity) ||
      (Buffer->Start < 0) || ((UINTN)Buffer->Start >= Capacity))
  {
    Buffer->Signature = PSTORE_SIGNATURE;
    Buffer->Start     = 0;
    Buffer->Size      = 0;
  }

  if (Length > Capacity) {
    Data   += Length - Capacity;
    Length  = Capacity;
  }

  Count = Length;
  if ((UINTN)Buffer->Size < Capacity) {
    UINTN  NewSize = (UINTN)Buffer->Size + Count;
    Buffer->Size = (INT32)((NewSize > Capacity) ? Capacity : NewSize);
  }

  Start = (UINTN)Buffer->Start;
  Buffer->Start = (INT32)((Start + Count) % Capacity);
  FirstPart = Capacity - Start;
  if (FirstPart > Count) {
    FirstPart = Count;
  }

  CopyMem ((VOID *)(Buffer->Data + Start), Data, FirstPart);
  if (FirstPart < Count) {
    CopyMem ((VOID *)Buffer->Data, Data + FirstPart, Count - FirstPart);
  }

  MemoryFence ();
}


/**
  Wipe the visible area with opaque black.

  Two mistakes are fixed here. The old code cleared Width * Height bytes
  contiguously, but the panel strides 1248 pixels per line for a 1220 pixel
  panel, so a contiguous clear wipes the wrong pixels. And a plain zero fill
  leaves the reserved byte at zero, which the inherited RGBA overlay treats as
  fully transparent, so LK's splash would show through the "cleared" screen.
**/
STATIC
VOID
ClearFrameBufferOpaque (
  VOID
  )
{
  UINTN   Row;
  UINTN   Col;
  UINT32  *Pixels;

  if ((mFbGeometry.Width == 0) || (mFbGeometry.Height == 0) ||
      (mFbGeometry.PitchBytes < mFbGeometry.Width * FB_BPP))
  {
    return;
  }

  Pixels = (UINT32 *)(VOID *)mFbGeometry.Base;

  for (Row = 0; Row < mFbGeometry.Height; Row++) {
    for (Col = 0; Col < mFbGeometry.Width; Col++) {
      Pixels[Col] = 0xFF000000U;
    }

    Pixels += mFbGeometry.PitchBytes / sizeof (UINT32);
  }

  WriteBackDataCacheRange (
    (VOID *)mFbGeometry.Base,
    (UINTN)mFbGeometry.PitchBytes * mFbGeometry.Height
    );
}

VOID
EFIAPI
PstoreLogBegin (
  VOID
  )
{
  PstoreWrite ((CONST UINT8 *)"K70U_UEFI_PSTORE_BEGIN\r\n", sizeof ("K70U_UEFI_PSTORE_BEGIN\r\n") - 1);
}

inline
STATIC
UINT8*
DrawPixel (
  IN UINT8  *Pixels,
  IN UINT32  PixelColor,
  IN UINT32  FontScale)
{
  // Repeat Action
  for (UINT8 i = 0; i < FontScale; i++) {
    // Save Pixel Color
    UINT32 Color = PixelColor;

    // Go theu each Byte
    for (UINT8 j = 0; j < FB_BPP; j++) {
      // Update Pixel Color
      *Pixels++ = (UINT8)Color;

      // Shift Pixel Color
      Color >>= 8;
    }
  }

  return Pixels;
}

inline
STATIC
UINT8*
DrawRow (
  IN UINT8  *Pixels,
  IN UINT32  RowData,
  IN UINT32  FontScale,
  IN UINTN   Stride)
{
  // Repeat Action
  for (UINT8 i = 0; i < FontScale; i++) {
    // Save Row Data
    UINT32 Data = RowData;

    // Go thru each Pixel
    for (UINT8 j = 0; j < FONT_WIDTH; j++) {
      // Set Pixel Color
      //
      // [k70u-fix 2026-11-02] LK leaves an RGBA overlay scanning the panel, so a
      // zero reserved byte means fully transparent and LK's own splash shows
      // through. Keep the background opaque, like the yunluo reference does.
      UINT32 PixelColor = (Data & 1) ? 0xFFFFFFFF : 0xFF000000;
      
      // Draw Pixel Color
      Pixels = DrawPixel (Pixels, PixelColor, FontScale);

      // Shift Row
      Data >>= 1;
    }

    // Append Stride
    Pixels += Stride;
  }
  
  return Pixels;
}

VOID
DrawGlyph (
  IN UINT8  *Pixels,
  IN UINT64  Glyph,
  IN UINT32  FontScale)
{
  // Calculate Stride
  UINTN Stride = FB_PITCH - (FONT_WIDTH * FontScale) * FB_BPP;

  // Split Glyph
  UINT32 TopGlyph    = (UINT32)(Glyph >> 32);
  UINT32 BottomGlyph = (UINT32)Glyph;

  // Set Inital Row Data
  UINT32 RowData = TopGlyph;

  // Go thru each Row
  for (UINT8 Row = 0; Row < 12; Row++) {
    // Switch Row Data
    if (Row == 6) {
      RowData = BottomGlyph;
    }

    // Draw Row
    Pixels = DrawRow (Pixels, RowData, FontScale, Stride);

    // Shift to next Row
    RowData >>= FONT_WIDTH;
  }
}

UINT8
GetFontScale ();

VOID
AdvanceNewLine (
  IN EFI_PHYSICAL_ADDRESS       FbBase,
  IN UINT64                     FbLength,
  IN EFI_FRAME_BUFFER_POSITION *CurrentPosition,
  IN EFI_FRAME_BUFFER_POSITION  MaxPosition)
{
  // Wait
  MicroSecondDelay (FB_DELAY_US);

  // Update Position
  CurrentPosition->XPos  = 0;
  CurrentPosition->YPos += 1;

  // Stop at the Bottom when the oldest Lines must stay readable
  if (CurrentPosition->YPos >= MaxPosition.YPos && FB_FREEZE) {
    CurrentPosition->YPos = FB_FROZEN_YPOS;
    return;
  }

  // Wrap to the Top, keeping the previous Screen visible
  if (CurrentPosition->YPos >= MaxPosition.YPos) {
    CurrentPosition->YPos = 0;
  }

  // Clear the Line about to be written and the next one, a blank Separator
  // between the newest and the oldest visible Lines
  UINTN  LineBytes = (UINTN)(FONT_HEIGHT - 4) * GetFontScale () * FB_PITCH;
  UINT32 NextYPos  = (CurrentPosition->YPos + 1 < MaxPosition.YPos) ? CurrentPosition->YPos + 1 : 0;
  ZeroMem ((VOID *)(mFbGeometry.Base + CurrentPosition->YPos * LineBytes), LineBytes);
  ZeroMem ((VOID *)(mFbGeometry.Base + NextYPos * LineBytes), LineBytes);
}

UINT8
GetFontScale ()
{
  // Use the Platform Scale when set
  if (FB_SCALE != 0) {
    return FB_SCALE;
  }

  // Get Smaller Display Dimension
  UINT32 ShorterDimension = (FB_WIDTH < FB_HEIGHT) ? FB_WIDTH : FB_HEIGHT;

  // Return Calculated Font Scale
  return (ShorterDimension < 426) ? 1 : (UINT8)(ShorterDimension / 426);
}

VOID
GetFbPositions (
  IN  EFI_PHYSICAL_ADDRESS        FbBase,
  IN  UINT64                      FbLength,
  IN  UINT8                       FontScale,
  OUT EFI_FRAME_BUFFER_POSITION **CurrentPosition,
  OUT EFI_FRAME_BUFFER_POSITION  *MaxPosition)
{
  EFI_FRAME_BUFFER_POSITION LocalMaxPosition;

  // Get Current Position
  *CurrentPosition = (EFI_FRAME_BUFFER_POSITION *)(FbBase + FbLength - sizeof (EFI_FRAME_BUFFER_POSITION));

  // Calculate Max Positions
  LocalMaxPosition.XPos = FB_WIDTH  / ((FONT_WIDTH  + 1) * FontScale);
  LocalMaxPosition.YPos = FB_HEIGHT / ((FONT_HEIGHT - 4) * FontScale);

  // Pass Max Position
  *MaxPosition = LocalMaxPosition;
}

VOID
WriteFrameBuffer (
  IN EFI_PHYSICAL_ADDRESS FbBase,
  IN UINT64               FbLength,
  IN UINT8                Character)
{
  EFI_FRAME_BUFFER_POSITION *CurrentPosition;
  EFI_FRAME_BUFFER_POSITION  MaxPosition;
  UINT8                     *Pixels;

  // Set Glyph Font
  STATIC CONST UINT64 GlyphFont[] = GLYPH_FONT;

  // Set Glyph Font Scale
  UINT8 GlyphFontScale = GetFontScale ();

  // Get Frame Buffer Positions
  GetFbPositions (FbBase, FbLength, GlyphFontScale, &CurrentPosition, &MaxPosition);

  // Ignore everything after the Log froze
  if (CurrentPosition->YPos == FB_FROZEN_YPOS) {
    return;
  }

  // Skip Invalid ACSII Characters
  if (Character >= 127) {
    return;
  }

  // Handle Control Characters
  if (Character < 32) {
    if (Character == '\f') {
      // Form feed: clear the whole screen and start again at the top left, so a
      // message that matters (the hand-off to a kernel) fills the screen.
      ClearFrameBufferOpaque ();
      CurrentPosition->XPos = 0;
      CurrentPosition->YPos = 0;
    } else if (Character == '\n') {
      AdvanceNewLine (FbBase, FbLength, CurrentPosition, MaxPosition);
    } else if (Character == '\r') {
      CurrentPosition->XPos = 0;
    }

    return;
  }

  // Skip leading Spaces
  if (CurrentPosition->XPos == 0 && Character == ' ') {
    return;
  }

  // Translate ACSII Character
  UINT64 Glyph = GlyphFont[Character - 32];

  // Calculate Glyph Dimension
  UINTN GlyphWidth  = (FONT_WIDTH  + 1) * GlyphFontScale;
  UINTN GlyphHeight = (FONT_HEIGHT - 4) * GlyphFontScale;

  // Set Glyph Pixels
  Pixels  = (VOID *)mFbGeometry.Base;
  Pixels += (UINTN)CurrentPosition->YPos * GlyphHeight * FB_PITCH;
  Pixels += (UINTN)CurrentPosition->XPos * GlyphWidth  * FB_BPP;

  // Draw Glyph
  DrawGlyph (Pixels, Glyph, GlyphFontScale);

  // Increase X Position
  CurrentPosition->XPos++;

  // Check Max X Position
  if (CurrentPosition->XPos >= MaxPosition.XPos) {
    AdvanceNewLine (FbBase, FbLength, CurrentPosition, MaxPosition);
  }
}

EFI_STATUS
GetFrameBufferMemory (
  OUT EFI_PHYSICAL_ADDRESS *Base,
  OUT UINT64               *Length)
{
  //
  // [k70u-fix 2026-11-02] LocateMemoryRegionByName() does not touch its output
  // parameter when the region is absent, so an uninitialised FbRegion left stack
  // garbage that was then used as the framebuffer base: the pixel writes and the
  // DC-by-MVA flush went to an untranslated address and raised a synchronous
  // exception. Zero it and honour the lookup status instead.
  //
  EFI_MEMORY_REGION_DESCRIPTOR FbRegion = { 0 };

  // Locate "Display Reserved" Memory Region
  if (EFI_ERROR (LocateMemoryRegionByName ("Display Reserved", &FbRegion)) &&
      EFI_ERROR (LocateMemoryRegionByName ("Display_Reserved", &FbRegion)))
  {
    return EFI_NOT_FOUND;
  }

  if ((FbRegion.Address == 0) || (FbRegion.Length == 0)) {
    return EFI_NOT_FOUND;
  }

  // Pass Frame Buffer Memory
  *Base   = FbRegion.Address;
  *Length = FbRegion.Length;

  return EFI_SUCCESS;
}

STATIC
VOID
LoadGeometry (
  IN EFI_PHYSICAL_ADDRESS  FbBase,
  IN UINT64                FbLength)
{
  CONST volatile FB_HANDOFF *Handoff;

  // Build-time Default
  mFbGeometry.Base       = (UINTN)FbBase;
  mFbGeometry.Width      = FixedPcdGet32 (PcdFrameBufferWidth);
  mFbGeometry.Height     = FixedPcdGet32 (PcdFrameBufferHeight);
  mFbGeometry.PitchBytes = mFbGeometry.Width * FB_BPP;

  // Handed-off Geometry, valid only once its Magic is set
  Handoff = (CONST volatile FB_HANDOFF *)(UINTN)(FbBase + FbLength - FB_HANDOFF_OFFSET);
  if (Handoff->Magic == FB_HANDOFF_MAGIC) {
    //
    // [k70u-fix 2026-11-02] The record lives in DRAM that a previous boot (or
    // the stock bootloader) left behind, so a stale or random value can look
    // like a valid magic. Only accept a geometry that is self-consistent and
    // fits the carveout, otherwise a bogus Width or Pitch would send the
    // console walking far outside the frame buffer.
    //
    if ((Handoff->Width != 0) && (Handoff->Height != 0) &&
        (Handoff->PitchBytes >= Handoff->Width * FB_BPP) &&
        (Handoff->PitchBytes <= (16U * 1024U * 1024U)) &&
        (Handoff->Base >= FbBase) && (Handoff->Base < FbBase + FbLength))
    {
      mFbGeometry.Base       = (UINTN)Handoff->Base;
      mFbGeometry.Width      = Handoff->Width;
      mFbGeometry.Height     = Handoff->Height;
      mFbGeometry.PitchBytes = Handoff->PitchBytes;
    }
  }
}

UINTN
EFIAPI
SerialPortWrite (
  IN UINT8 *Buffer,
  IN UINTN  NumberOfBytes)
{
  EFI_STATUS           Status;
  EFI_PHYSICAL_ADDRESS FbBase;
  UINT64               FbLength;

  PstoreWrite (Buffer, NumberOfBytes);

  // Get Frame Buffer Memory
  Status = GetFrameBufferMemory (&FbBase, &FbLength);
  if (EFI_ERROR (Status)) {
    return 0;
  }

  // Use the Geometry of the Frame Buffer that is really scanned out
  LoadGeometry (FbBase, FbLength);

  // Get Interrupts State
  BOOLEAN InterruptState = ArmGetInterruptState ();

  // Disable Interrupts
  if (InterruptState) {
    ArmDisableInterrupts ();
  }

  // Write Debug Message to Frame Buffer
  for (UINTN i = 0; i < NumberOfBytes; i++) {
    WriteFrameBuffer (FbBase, FbLength, *Buffer++);
  }

  // Enable Interrupts
  if (InterruptState) {
    ArmEnableInterrupts ();
  }

  //
  // [k70u-fix 2026-11-02] Clamp the flush to the mapped display region. A cache
  // maintenance operation on an untranslated address traps, and doing it from the
  // logger turns a single fault into the recursive exception seen on device.
  //
  if ((mFbGeometry.Base >= (UINTN)FbBase) &&
      (mFbGeometry.Base < (UINTN)(FbBase + FbLength)))
  {
    UINTN FlushLength = (UINTN)mFbGeometry.PitchBytes * (UINTN)mFbGeometry.Height;

    if ((FlushLength == 0) || (FlushLength > (UINTN)FbLength)) {
      FlushLength = (UINTN)FbLength;
    }

    WriteBackInvalidateDataCacheRange ((VOID *)mFbGeometry.Base, FlushLength);
  }

  return NumberOfBytes;
}

UINTN
EFIAPI
SerialPortRead (
  OUT UINT8 *Buffer,
  IN  UINTN  NumberOfBytes)
{
  return 0;
}

BOOLEAN
EFIAPI
SerialPortPoll ()
{
  return FALSE;
}

EFI_STATUS
EFIAPI
SerialPortSetControl (IN UINT32 Control)
{
  return EFI_UNSUPPORTED;
}

EFI_STATUS
EFIAPI
SerialPortGetControl (OUT UINT32 *Control)
{
  return EFI_UNSUPPORTED;
}

EFI_STATUS
EFIAPI
SerialPortSetAttributes (
  IN OUT UINT64             *BaudRate,
  IN OUT UINT32             *ReceiveFifoDepth,
  IN OUT UINT32             *Timeout,
  IN OUT EFI_PARITY_TYPE    *Parity,
  IN OUT UINT8              *DataBits,
  IN OUT EFI_STOP_BITS_TYPE *StopBits)
{
  return EFI_UNSUPPORTED;
}

EFI_STATUS
EFIAPI
SerialPortInitialize ()
{
  return EFI_SUCCESS;
}
