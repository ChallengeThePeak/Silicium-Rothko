#ifndef ROTHKO_STAGE_H
#define ROTHKO_STAGE_H
#include <Base.h>
// Encode the last phase in LENGTH without changing MODE/reset routing.
STATIC inline VOID RothkoStage (UINT32 Stage) {
  volatile UINT32 *Rgu = (volatile UINT32 *)(UINTN)0x1C00B000;
  Rgu[1] = ((8U + Stage) << 11) | 8U;
  __asm__ volatile ("dsb sy" ::: "memory");
  Rgu[2] = 0x1971;
  __asm__ volatile ("dsb sy" ::: "memory");
}
STATIC inline VOID RothkoStageFail (UINT32 Stage, UINT64 Status) {
  UINT64 Beacon = 0x5354000000000000ULL | ((UINT64)Stage << 32) | (Status & 0xFFFFFFFFULL);
  __asm__ volatile ("msr daifset, #2\nmov x30, %0\n1: b 1b" :: "r"(Beacon) : "x30", "memory");
}
#endif
