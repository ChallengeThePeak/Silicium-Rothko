

## Fresh device strings capture: entry probe executed (2026-10-31)
Device VKMZZDEI4H759TRS connected, current slot _a, Android boot_completed=1.
Ran strings -a on expdb on the device, then adb pull. Saved logs/device-expdb-strings-20261031-205609.txt (2042128 B), SHA256 9f5082fbde808efde82ba51502a80e4423ba476a0cf6abb1791ec02e32dbc420.
Three repeated records contain kernel_sz=0x000483da (295898, identical to entry probe compressed payload), WDT LENGTH=0x3800, and CPU PC=0x40000070, exactly the probe _Park branch at shim offset 0x70. PSTATE=0x3c5, SP=0 are consistent with the stackless EL1h entry probe. WDT time ~10.35 seconds is measured from firmware boot origin, not shim entry.
This proves the diagnostic kernel passed LK decompression and ATF handoff and executed the probe. Probe intentionally never copies FD or enters SEC; this watchdog stop is expected, not a UEFI crash. Repeated text may duplicate records, so do not infer three distinct attempts.
The same retained sequence reports vbmeta_a HASH_MISMATCH, followed by img_auth_required=0, avb_ret=0, header loads, decompression and the probe PC. Thus vbmeta validation warns but does not block this attempt. Local flags3 vbmeta is 8192 B, flags=3, SHA256 1fc27c867cc4b8045b35ad0c01c4702beeecb426f3472174ef35e75d515136b4. No device vbmeta readback hash was captured, so file identity is not asserted.
No booting-linux/final-jump strings were found in this strings capture despite actual probe execution: absence of these strings is demonstrably insufficient to claim no handoff.
Next isolate normal candidate FD copy, cache publication and SEC execution using stage-specific register/PC evidence. Do not repeat AVB-only changes as a fix.


## Current device partition readback (2026-10-31 22:22)
Read-only adb root readback confirms the current state independently of expdb:
- boot_a is 67108864 B, SHA256 06ad47c867ee2647856b0bb2f3e4c7b37104056facc4488891c6b2ad6474ce96.
- boot_a header is Android v4 with kernel_size=0x15141fe and kernel bytes 02 21 4c 18 (stock LZ4 Linux), not the stage-coded candidate kernel_size=0x48582 and gzip 1f8b.
- vbmeta_a is 8388608 B, SHA256 b6028bbe43a7b1d0610f8de96c3d602751bbdc46a2d7c24cb3e0f53a9a1479af. Its first 8192 bytes exactly match the flags=3 companion (SHA256 1fc27c867cc4b8045b35ad0c01c4702beeecb426f3472174ef35e75d515136b4); 56 nonzero bytes exist after that padded image.
- Therefore the low-check vbmeta is present on the device, while the stage-coded boot image is not present in boot_a at capture time. The latest expdb cannot be used as a test result for the stage-coded image.
- The historical fastboot flash records in strings show 0x4000000 downloads, but they do not identify the payload hash; current partition readback is authoritative for the present state.
