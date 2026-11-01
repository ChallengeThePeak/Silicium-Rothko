# K70U stage coded candidate

The 7 second entry probe proved that LK decompression and the ATF handoff work:
expdb recorded `pc=0x40000070`, exactly the probe park loop. The next image keeps
the normal BootShim plus 2 MiB UEFI FD path and adds phase codes to the inherited
watchdog `LENGTH` register. It also feeds the watchdog before SEC has timers.

Image:

`work/evidence-20261031/boot-rothko-uefi-stage-coded-20261031-avbf.img`

SHA-256:

`18eced1a56c33b9b34d35d037cb2f8b97832f6bf704638d1cd28fa9cc7b78a16`

The 64 MiB AVBf image has a v4 header, `kernel_size=296322`, a 2 MiB FD, and a
424 byte AVB hash descriptor. The verifier and AVB digest check pass. The final
UEFI FD is `d55a4f9d5cb5a85475c810f8b4824ac50a0c723486e667ee867650b30a847948`.

The written `LENGTH` values are phase markers. The high part is the phase code
and the low byte is `0x08`. The ATF expdb printer masks the low control bits,
so a written `0x1808` may be displayed as `[RGU]LENGTH:0x1800`; use the high
part for the phase:

| LENGTH | Phase |
|---|---|
| `0x1808` | Shim entered before FD copy |
| `0x2008` | FD copy complete, before branching to FD |
| `0x2808` | SEC module entry after cache and entry setup |
| `0x5008` | SEC platform initialization |
| `0x5808` | SEC serial initialization |
| `0x6008` | SEC memory map and MMU initialization |
| `0x6808` | CPU HOB creation |
| `0x7008` | Platform PEIM |
| `0x7808` | FV decompression |
| `0x8008` | DXE Core load |
| `0x9008` | ArmGicDxe |
| `0x9808` | TimerDxe |
| `0xa008` | RothkoWatchdogDxe |
| `0xa808` | Display DTB read |
| `0xb008` | Display scanout probe |
| `0xb808` | GOP installation |
| `0xc008` | Display refresh |
| `0xc808` | Display entry completed |

If the device resets, the latest `[RGU] LENGTH` in the next strings capture is
the only value needed to identify the last phase reached. A phase code near
`0x1808` proves Shim entry; codes `0x5008` through `0x8008` isolate SEC; codes
from `0x9008` onward isolate DXE. A SEC synchronous exception also encodes an
`0x53540000...` LR beacon with `EFI_STATUS` in the low 32 bits.

This is the one normal bring-up image to test for this round. The flags=3 vbmeta
companion remains the same; the previous probe showed `HASH_MISMATCH` followed
by `img_auth_required=0` and `avb_ret=0`, so vbmeta is not the current blocker.
