# 显示修复：alpha 不透明 + stride 正确 + 发布真实几何（2026-11-02）

## 参考实现
`D:\漏洞\YunluoUEFI-MU`（云罗）的 `repo/patches/0003`、`0004` 给出了同一类问题的现成修法：
面板按 **stride** 扫描（云罗 2000 可见 / 2048 行距），而 GOP 没有 alpha 契约，
LK 留下的却是 RGBA 合成层。

## rothko 的对应事实
- 可见宽 1220、**行距 1248 像素（4992 字节）**（OVL 图层 pitch 实测；内核 mtkfb.txt 同值）
- LK 的 OVL 是 RGBA 合成

## 三处修复
1. **背景像素 alpha**：`FrameBufferSerialPortLib` 里
   `PixelColor = (Data & 1) ? 0xFFFFFFFF : 0x00000000` → 背景改成 `0xFF000000`。
   原来背景 alpha=0，在 RGBA 合成下等于全透明，LK 的开机 logo 直接透出来 → 花屏。
2. **清屏**：原来 `ZeroMem(FbBase, FB_WIDTH * FB_HEIGHT * FB_BPP)`（按宽度连续清，且全 0）。
   改为 `ClearFrameBufferOpaque()`：按行距逐行、只清可见宽度、每像素写 `0xFF000000`，
   并回写 cache。
3. **发布真实几何**：帧缓冲控制台每次写都读 `FrameBufferHandoff` 记录
   （`"FBGO"`，位于 Display Reserved 末尾 `Base+Length-0x40`）。树里只有
   `shengPkg/Drivers/ShengGopLogDxe` 会发布，我们这边没人发布 → 控制台一直用兜底
   `PitchBytes = Width * BPP = 4880`，与硬件 4992 差 28 像素，每行错位。
   现在 **SEC（开画前）** 与 **RothkoDisplayDxe（拿到 OVL 实测 pitch 后）** 都发布一次。
4. **GOP blt 之后强制不透明**：`RothkoDisplayDxe` 的 Blt 在 `FrameBufferBlt` 之后把目标区域
   `|= 0xFF000000`，对应云罗补丁里 "Keep the scanout opaque even when Blt's reserved byte is zero"。

SEC 需要 PCD，补充 `MemoryInitPeiLib.inf` 的 `[FixedPcd]`：
PcdFrameBufferWidth / PcdFrameBufferHeight / PcdFrameBufferStride。
