#
# Include from the Rothko platform DSC.
#
# [k70u 2026-11-04] The payload volume is located at run time, not by a fixed
# offset: LK assembles the initrd envelope from the vendor ramdisk followed by
# the init_boot ramdisk, and the stock vendor ramdisk is ~52 MiB of Android
# payload, so the volume we want never starts at a stable offset.  A zero size
# tells UniXNURamDiskDxe to scan for the FAT32 VBR and take the length from that
# volume's own BPB.  Set both to non-zero to pin a slice explicitly instead.
#
[PcdsFixedAtBuild]
  gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskOffset|0x00000000
  gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskSize|0x00000000
