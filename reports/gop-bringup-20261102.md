# 显示点亮记录（2026-11-02）

## 里程碑
UEFI 完整启动到 BDS，**GOP 已安装，屏幕点亮**。

## 三轮修复
1. **驱动没进 FV**：`APRIORI.inc` 只列 GUID，`DXE.inc` 没写 INF，且 DSC 缺
   `[Components]` 登记 → EDK2 error F001。移植驱动本体 + 三处登记后解决。
2. **静默 EFI_INVALID_PARAMETER**：驱动用 `LocateMemoryRegionByName("LK DTB")`
   找设备树，我们的内存表里叫 "Incoming DTB" → 改名并改为保留区（LK 交的是活设备树，
   不能让 GCD 分配出去）。
3. **0 validated scanout**：驱动的图层判据是 dali(MT6991) 的规则，从未在 rothko 上
   执行过。只保留"这是全屏扫描层"的硬门（CFMT=RGBA、SRC_SIZE=1220|2712<<16，
   地址/尺寸/对齐/落在 carveout 内），其余位降级为告警。

## 离线实锤来源
- `work/mtkfb.txt`：内核在 rothko 上的 `mtk_ovl_layer_config OVL0_2L idx:0
  fmt:0x34324258(XB24) addr:0x3ef000000 con:0x10021ff offset:0x0` +
  `mtk_plane_atomic_update en1 pitch4992 fmt:XB24 x0 y0 w1220 h2712`
- `work/modules/lib/modules/mediatek-drm.ko`（未 strip）：OVL 相关符号齐全
- 设备 DT：`/soc/disp-ovl0-2l@14402000`、`/soc/disp-mdp-rdma0@14014000`、
  `/soc/ovl-rsz0@14406000`

## 已知遗留
顶部花屏且定格：GOP 走 1220 宽、OVL 图层 pitch 是 1248 像素，且 LK 留下的
overlay 图层与 logo 仍叠在上面。属于显示链路已通、图层内容未清理的阶段状态，
不是崩溃。

## 上游推送
- `ChallengeThePeak/Silicium-Rothko` 的 `uefi/rothko` → `61bf05a`
- 同仓库 `basecore/rothko` → `78c561c`
