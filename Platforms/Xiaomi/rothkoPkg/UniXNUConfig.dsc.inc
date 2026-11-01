#
# Include from the Rothko platform DSC.
# Offset is the normal vendor-ramdisk prefix in the v4 LK initrd envelope.
# Set the exact sector-aligned FAT image size when the payload image is built.
#
[PcdsFixedAtBuild]
# [build-fix 2026-11-02] 该 PCD 未在任何 DEC 中声明，且无消费者，上游此处不一致；暂时注释
#gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskOffset|0x02719743
# [build-fix 2026-11-02] 该 PCD 未在任何 DEC 中声明，且无消费者，上游此处不一致；暂时注释
#gUniXNUPkgTokenSpaceGuid.PcdUniXNURamDiskSize|0x00100000
