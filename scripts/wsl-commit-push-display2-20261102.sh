#!/bin/bash
# 提交显示修复并推送（uefi/rothko + main）
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full

cd "$R" || exit 1
echo "=== 改动的文件 ==="
git status --short | grep -v "^??" | head -20
echo "--- 未跟踪（不提交）---"
git status --short | grep "^??" | head -5

echo
echo "=== 提交 ==="
git add Platforms/Xiaomi/rothkoPkg/Drivers/RothkoDisplayDxe/RothkoDisplayDxe.c \
        Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c \
        Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c \
        Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPeiLib.inf 2>/dev/null
git commit -q -F - <<'MSG'
fix(k70u): 修好显示——alpha 不透明、stride 正确、持续推帧

屏幕能亮但内容是花的、定在顶部不动。三个原因，都与 dali(MT6991) 参考实现的
差异有关：

1. 背景像素 alpha=0
   FrameBufferSerialPortLib 写背景用 0x00000000，而 LK 留下的 OVL 图层是 RGBA
   合成，保留字节为 0 等于全透明，LK 自己的开机画面直接透出来。改成
   0xFF000000，与 yunluo 参考实现 "Keep the scanout opaque even when Blt's
   reserved byte is zero" 一致。

2. 清屏按可见宽连续清
   原来是 ZeroMem(FbBase, FB_WIDTH * FB_HEIGHT * FB_BPP)：面板行距是 1248 像素
   （4992 字节）而可见宽 1220，连续清会清错位置；而且清出来是全 0，又是透明。
   改为 ClearFrameBufferOpaque()：按行距逐行、只清可见宽、每像素 0xFF000000、
   写回 cache。

3. 没人发布真实几何，控制台一直用错 stride
   帧缓冲控制台每次写都读 FrameBufferHandoff 记录（"FBGO"，位于 Display
   Reserved 末尾 Base+Length-0x40），没有它就退回 Width * BPP = 4880，与硬件
   4992 差 28 像素，每行错位。树里只有 shengPkg/ShengGopLogDxe 会发布这个记录，
   rothko 这边没有。现在由 RothkoDisplayDxe 在拿到 OVL 实测 pitch 后发布一次。
   同时给记录加合法性校验：位置在 DRAM 里，可能残留上次开机的垃圾，Width/
   Height/Pitch/Base 必须自洽且落在 carveout 内才采信。

另外两处：
- RothkoDisplayDxe 的 GOP blt 之后把目标区 |= 0xFF000000，与第 1 条同理。
- Refresh() 不再只在 GOP blt 时推帧。原日志库直接把 UEFI log 写进帧缓冲，不走
  GOP，dirty 门控导致这些内容永远推不出去，屏幕停在最后一次推的帧。现在每个
  节拍都推（200 ms），面板上会随输出逐行出现 log——yunluo 参考实现同样如此。

SEC 阶段不参与这些改动，避免在第一条日志之前引入变量。
MSG
git log --oneline -1

echo
echo "=== 推送 ==="
timeout 300 git push origin uefi/rothko 2>&1 | tail -3
OLD=$(git rev-parse refs/remotes/origin/main 2>/dev/null || echo "")
git fetch origin main:refs/remotes/origin/main 2>&1 | tail -1
OLD=$(git rev-parse refs/remotes/origin/main)
timeout 300 git push origin uefi/rothko:main --force-with-lease=main:"$OLD" 2>&1 | tail -3

echo
echo "=== 远端确认 ==="
timeout 120 git ls-remote --heads origin 2>&1 | head -8
