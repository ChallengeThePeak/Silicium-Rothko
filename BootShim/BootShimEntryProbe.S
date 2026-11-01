// Headless LK-entry probe: optional pmsg stores, no stack/framebuffer/UEFI.
// A reset after PROBE_DELAY_S is the observable result, not a pstore log.
#ifndef PROBE_DELAY_S
#define PROBE_DELAY_S 15
#endif
#ifndef PROBE_DIRECT_RESET
#define PROBE_DIRECT_RESET 0
#endif
#ifndef PROBE_PSTORE
#define PROBE_PSTORE 0
#endif

.section .text,"ax",%progbits
.global _Head
_Head:
  b     _Start
  .long 0
  .quad 0                    // Linux Image text_offset, not an absolute FD base.
  .quad _End - _Head
  .quad 0xA                  // Stock Image flags: 4 KiB pages, any placement.
  .quad 0
  .quad 0
  .quad 0
  .ascii "ARM\x64"
  .long 0

_Start:
#if PROBE_PSTORE == 1
  // Replace only the pmsg ring; publish its signature after the data.
  ldr   x9, =0x480F0000
  str   wzr, [x9]
  dsb   sy
  adr   x10, _PmsgText
  add   x11, x9, #12
  mov   x12, #(_PmsgTextEnd - _PmsgText)
  mov   x13, x12
_PmsgCopy:
  ldrb  w14, [x10], #1
  strb  w14, [x11], #1
  subs  x13, x13, #1
  b.ne  _PmsgCopy
  dsb   sy
  str   w12, [x9, #4]
  str   w12, [x9, #8]
  ldr   w14, =0x43474244
  str   w14, [x9]
  mov   x10, x9
  add   x11, x9, #(12 + _PmsgTextEnd - _PmsgText)
_PmsgClean:
  dc    cvac, x10
  add   x10, x10, #8
  cmp   x10, x11
  b.lo  _PmsgClean
  dsb   sy
#endif
#if PROBE_DIRECT_RESET == 0
  mrs   x8, CurrentEL
  mrs   x4, cntfrq_el0
  cbz   x4, _Stopped
  mov   x5, #PROBE_DELAY_S
  mul   x4, x4, x5
  isb
  mrs   x5, cntvct_el0
_Wait:
  isb
  mrs   x6, cntvct_el0
  sub   x6, x6, x5
  cmp   x6, x4
  b.lo  _Wait
#endif

  mov   w0, #9
  movk  w0, #0x8400, lsl #16  // PSCI SYSTEM_RESET, SMC conduit from stock FDT.
  mov   x1, xzr
  mov   x2, xzr
  mov   x3, xzr
  smc   #0
_Stopped:
  b     _Stopped

#if PROBE_PSTORE == 1
_PmsgText:
  .ascii "K70U_AVB_PMSG_ENTRY_V1\r\n"
_PmsgTextEnd:
#endif
.ltorg
.balign 4096
_End:
