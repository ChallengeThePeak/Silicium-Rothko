#!/bin/bash
# 提交显示移植并推送
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full
SSHURL="git@github.com:ChallengeThePeak/Silicium-Rothko.git"

echo "=== 1) Mu_Basecore: RothkoStage.h ==="
cd "$R/Mu_Basecore" || exit 1
git add MdePkg/Include/Library/RothkoStage.h
git commit -q -F - <<'MSG'
feat(k70u): 移植 RothkoStage.h，供 RothkoDisplayDxe 使用

该头文件提供 RothkoStage()/RothkoStageFail()：把阶段号写进 MTK 看门狗的
LENGTH 寄存器（不改变 MODE 与复位路由），并在失败时用 DAIF 屏蔽中断后停在
指定地址，便于从看门狗复位原因判断固件停在哪一步。

RothkoDisplayDxe 在进入时按阶段号打点，依赖这个头文件。
MSG
git log --oneline -1

echo
echo "=== 2) uefi-full: 显示移植 ==="
cd "$R" || exit 1
git add Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe \
        Platforms/Xiaomi/rothkoPkg/Include/DXE.inc \
        Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc \
        Platforms/Xiaomi/rothkoPkg/rothko.dsc \
        Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c \
        Silicon/Silicium/SiliciumPkg/SiliciumPkg.dec \
        Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc \
        Mu_Basecore
git commit -q -F - <<'MSG'
feat(k70u): 移植 RothkoDisplayDxe，接上 GOP 与 DSI 命令模式推帧

rothkoPkg 之前没有显示驱动：APRIORI 里只列了 RothkoDisplayDxe 的 GUID，
DXE.inc 没写 INF，因此该模块从未进入 FD（2026-11-01 的 FV 审计已确认）。
本次把已通过反汇编核对的驱动整体移植进来。

驱动行为（沿用 dali/MT6991 上验证过的做法）：
  1. 从 LK 交接的设备树（x0，经 SEC 存进 gSiliciumEntryArgHobGuid）取帧缓冲
     基址与大小；
  2. 探测 LK 实际在扫描的 OVL 图层，回读真实的图层地址、pitch 与颜色格式；
  3. 在验证过的图层上安装 GOP，并镜像其它活动全屏图层，避免旧 overlay 盖住新字；
  4. 脏帧时 clean to PoC、arm 继承来的 mutex 组，再脉冲 DSI_START 0->1；
  5. 不写 DSC、MMSYS bypass 与 crossbar 寄存器——那些是 LK 的配置，原样信任。

配套改动：
- SiliciumPkg.dec/dsc.inc：新增 PcdFrameBufferStride（0x0000A006）
- rothko.dsc：登记 [Components]、补 PCD Width=1220 Height=2712 ColorDepth=32
  Stride=1248 Delay=0；面板几何沿用 dali 验证值与 LK 交接的 atag,videolfb
- MemoryMapLib.c：加回 Display Reserved 0xFD91F000+0x26E0000（LK 交接的
  framebuffer carveout），并加入驱动要探测的 9 个显示 MMIO 窗口
  （MMSYS / 两个 MUTEX / OVLSYS0-1 / DISPSYS1 / DSC0 / DSI0 / MIPI TX0）
- 设备树区域改名 "LK DTB"（驱动按这个名字查找）并改为保留区：LK 交过来的是
  活设备树，GCD 不能把它分配出去

MT6989 与 MT6991 的差异：图层检查只保留“这就是全屏扫描层”的硬门（CFMT=RGBA、
SRC_SIZE=1220|2712<<16，以及地址/尺寸/对齐），其余描述合成链路接线的位
（PITCH_MSB 高位、RDMA_CTRL、OFFSET、CLIP、DATAPATH_EXT、CLRFMT_EXT）
降级为告警并统一打印——这些位在两颗 SoC 上编码不同，用 MT6991 的规则会误杀
rothko 的全屏图层（表现为 0 validated scanout、推帧被禁）。
MSG
git log --oneline -1

echo
echo "=== 3) 推送 ==="
cd "$R/Mu_Basecore" && git remote set-url origin "$SSHURL"
timeout 300 git push origin k70u-port-20261102:basecore/rothko 2>&1 | tail -4
cd "$R" || exit 1
git remote set-url origin "$SSHURL"
timeout 600 git push origin uefi/rothko 2>&1 | tail -4
echo
timeout 120 git ls-remote --heads origin 2>&1 | head -6
