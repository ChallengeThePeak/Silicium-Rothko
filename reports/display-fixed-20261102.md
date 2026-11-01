# 显示修好（2026-11-02）

## 症状演进
1. 移植 RothkoDisplayDxe 后：GOP 装上，但 `0 validated scanout` → 推帧被禁 → 无画面
   （dali 的图层判据误杀 MT6989：唯一违规是 PITCH_MSB 的 bit20）
2. 放宽判据后：屏幕亮，能推帧（`frame 1/2 submitted`），但顶部花屏且定住
3. 蓝屏→黑屏：蓝色是驱动的诊断填充 `0xFF102030`（证明推帧链路通），
   黑色是日志库按可见宽连续清屏所致

## 三个真原因（与 dali/MK6991 参考实现的差异）
1. **背景像素 alpha=0**：LK 留下的 OVL 是 RGBA 合成，保留字节 0 = 全透明，
   LK 的开机画面直接透出。改为 `0xFF000000`。
2. **清屏按可见宽连续清**：面板行距 1248 像素（4992 字节）而可见宽 1220，
   连续清会清错位置，且全 0 仍是透明。改为按行距逐行写不透明黑 + 写回 cache。
3. **没人发布真实几何**：帧缓冲控制台每次写都读 `FrameBufferHandoff`（"FBGO"），
   没有就退回 `Width * BPP = 4880`，与硬件 4992 差 28 像素，每行错位。
   现在由 RothkoDisplayDxe 在拿到 OVL 实测 pitch 后发布，并给记录加合法性校验
   （位置在 DRAM，可能残留上次开机的垃圾）。

## 另外两处
- GOP blt 之后目标区 `|= 0xFF000000`（同第 1 条）
- `Refresh()` 不再只在 GOP blt 时推帧：日志库直接写帧缓冲、不走 GOP，
  dirty 门控导致 log 永远推不出去。现在每 200 ms 推一次。

## 参考来源
- `D:\漏洞\YunluoUEFI-MU\repo\patches\0003-SimpleFb-stride-alpha-cache-ovl.patch`
- `D:\漏洞\YunluoUEFI-MU\repo\patches\0004-FrameBufferSerialPortLib-stride.patch`
  （云罗：可见 2000 / 行距 2048，症状与修法同构）

## GitHub
- `main` = `d7021cd`，`uefi/rothko` = `d7021cd`
- `basecore/rothko` = `78c561c`，`notes/k70u-workspace-20261102` = 工作区
- 旧 main 备份：`archive/main-before-k70u` = `6b1f2dd`
