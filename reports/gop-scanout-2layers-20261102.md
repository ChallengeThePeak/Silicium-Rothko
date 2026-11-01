# 扫描层双层与顶部花屏（2026-11-02）

## 实测日志
```
ROTHKO: LIN L0 soft=00000004 con=000021FF pitchmsb=00100000 rdma=00000001 size=0A9804C4 off=0 clip=0 dpcon=07000001 dpext=0 clrfmt=0
ROTHKO: LIN L1 soft=00000004 ...
ROTHKO: 2 validated scanout layer(s)
ROTHKO: GOP mode 1220x2712 pitch=1248 format=1 size=CE9400 scanouts=2
ROTHKO: mutex id=0 bank=0 en=0 sof=0 mod0=5080B735 mod2=000001A7 ... banks=7
ROTHKO: frame 1 submitted, dsi status=800A0004
ROTHKO: refresh enabled
ROTHKO: frame 2 submitted, dsi status=800B0016
```

## 结论
1. **上一轮唯一被降级的软判据是 `PITCH_MSB` 的 bit20**（`soft=0x0004`）。MT6989 上该位另有
   用途，dali(MT6991) 的 `PitchMsb & (BIT16|BIT20)` 规则会误杀 rothko 的全屏图层。
   其余寄存器（RDMA=0x1、OFFSET=0、CLIP=0、DATAPATH_EXT=0、CLRFMT_EXT=0）本来就合规。
2. **推帧链完整可用**：mutex 探测到 7 个 bank，bank0 的 MOD0=0x5080B735 含 DSI0 选择位；
   DSI_START 0->1 连续两帧提交成功，状态寄存器可读回。
3. **顶部花屏的成因**：扫描链上有两个全屏图层
   - L0：addr=FD91F000（LK 帧缓冲），pitch=4992 字节 = 1248 像素
   - L1：addr=FE612000（LK 的 UI/logo 层），pitch=4880 字节 = 1220 像素
   驱动把 GOP 的内容镜像进两个扫描层，于是 LK 的旧 logo 与新文字叠加；
   同时 GOP 按 1220 宽写、OVL 按 1248 像素步进，行间错位形成斜纹。

## 下一步（任选）
- 停用 L1 这层（OVL EN/CLRFMT），让 L0 独占扫描；
- 让控制台按 1248 像素 pitch 步进（PCD Stride 已是 1248，需核对文本步进）；
- 或做一次全屏重绘覆盖 LK 残留。

## GitHub
- `main` = `61bf05a`（原 6b1f2dd 旧树备份在 `archive/main-before-k70u`）
- `uefi/rothko` = `61bf05a`，`basecore/rothko` = `78c561c`
- `notes/k70u-workspace-20261102` = 工作区报告与脚本
