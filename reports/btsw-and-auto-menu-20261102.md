# 颜色实锤（BTSW）+ 菜单自动进 BootOrder（2026-11-02 17:30）

## 一、推帧已彻底修好（pstore 实锤）

```
ROTHKO: frame 2 submitted, dsi status=800A0004
ROTHKO: refresh enabled
ROTHKO: refresh 25 frames, dsi status=800B5016
ROTHKO: refresh 75 frames, dsi status=800B5016
... 每 5 秒一条，一路涨到 2475 frames
```

去掉 `DSI_BUSY` 门控后推帧持续稳定，状态值不再变化，说明 DSI 命令通道正常。
之前"屏幕定住"就是第 3 帧之后全被这道门禁丢掉。

## 二、屏幕颜色错乱的实锤：L_CON_BTSW 没开

离线证据（`work/mtkfb.txt`，内核在同一块面板上的实际配置）：

```
mtk_ovl_layer_config OVL0_2L idx:0 fmt:0x34324258(XB24) con:0x10021ff offset:0x0
```

我们的驱动从 LK 继承到的值是：

```
ROTHKO: OVL 14402000 L0 con=000021FF
ROTHKO: OVL 14402000 L1 con=000021FF
```

**两者只差 BIT24（0x1000000）**，而 BIT24 就是 `L_CON_BTSW`（驱动第 154 行早已定义，
第 479 行还把它的状态记进 `mScanoutByteSwap`，但从没用它做任何事）。

原因链：
- EDK2 的 `EFI_GRAPHICS_OUTPUT_BLT_PIXEL` 字节序是 **Blue, Green, Red, Reserved**
- 面板像素格式 XB24，内存序 **B, G, R, X**
- OVL 不开 BTSW 时按 **R, G, B, A** 解释这一层
- → 红蓝互换 → 屏幕上出现品红、蓝、绿的块，而布局和文字位置都是对的

Linux 对这个面板配的是 `con=0x10021ff`（BTSW 打开），LK 交接时是关的。
**修法**：在收集扫描层之前，对每层 `OVL_CON |= L_CON_BTSW`。

## 三、菜单自动显示：把 BootManagerMenu 放进 BootOrder

`SiliciumPkg.dsc.inc`：

```
gEfiMdeModulePkgTokenSpaceGuid.PcdBootManagerInBootOrder|TRUE     (原 FALSE)
```

原来菜单不在 BootOrder，必须按音量上热键才进得去。本次实测：

```
K70U-BDS: EnterBootManager = 0        ← 没按到
[Bds]Booting UniXNU                   ← 于是按 BootOrder 直接启动 UniXNU
Error: Image at 000BF2B8000 start failed: Aborted
```

屏幕上的 "UniXNU 大字" 是 BDS 的 `Booting UniXNU` 提示，不是菜单；
而且 UniXNU 自己返回了 `EFI_ABORTED`（XNU 引导还没接完，属预期）。

设成 TRUE 后，超时结束就直接进 Boot Manager 菜单，不需要任何按键。
`PcdPlatformBootTimeOut` 已从 3 秒改成 10 秒。

## 四、还没做的
- **电源键做不了菜单确认**：MT6363 走 SPMI/PMIF，树里没有对应驱动，
  菜单目前只能用音量上/下移动，无法回车选中。
- UniXNU 启动返回 Aborted，需要继续接 XNU 引导。

## 五、产物

| 文件 | SHA-256 |
| --- | --- |
| `bringup/boot-k70u-uefi-menu5-20261102.img` | `55b2153b8c992d2bc0d295a41fc9a7108a0d78346b00ac0a38f909c9b185886c` |
| `bringup/init_boot-k70u-uefi-menu5-20261102.img` | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-menu5-20261102.fd` | `ecc53f523e63fbf8900631bf7ee7fd8469bf899a789ed2de0d2ce7d88c2d6c39` |
