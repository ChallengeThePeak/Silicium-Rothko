#ifndef ROTHKO_DISPLAY_BOUNDS_H
#define ROTHKO_DISPLAY_BOUNDS_H

#include <Base.h>

STATIC
BOOLEAN
RothkoSpanFits (
  IN UINT64  Base,
  IN UINT64  Length,
  IN UINT64  Address,
  IN UINT64  Bytes
  )
{
  if ((Bytes == 0) || (Bytes > Length) || (Address < Base) ||
      (Length > MAX_UINT64 - Base))
  {
    return FALSE;
  }

  return Address - Base <= Length - Bytes;
}

STATIC
BOOLEAN
RothkoRectFits (
  IN UINTN  X,
  IN UINTN  Y,
  IN UINTN  Width,
  IN UINTN  Height,
  IN UINTN  LimitX,
  IN UINTN  LimitY
  )
{
  return (Width != 0) && (Height != 0) &&
         (X < LimitX) && (Y < LimitY) &&
         (Width <= LimitX - X) && (Height <= LimitY - Y);
}

#endif
