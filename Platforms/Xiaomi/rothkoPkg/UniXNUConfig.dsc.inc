#
# Include from the Rothko platform DSC.
# Offset is the normal vendor-ramdisk prefix in the v4 LK initrd envelope.
# Set the exact sector-aligned FAT image size when the payload image is built.
#
[PcdsFixedAtBuild]
  gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskOffset|0x02719743
  gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskSize|0x00100000
