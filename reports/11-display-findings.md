# 11 — 显示点亮实验记录（rothko / MT6989）

日期：2026-10-22
结论先行：**boot 链已完全打通，payload 能在真机上执行并复位；显示卡在 DSI CMD 面板的“推帧”环节。**

## 1. 已确认的事实

| 项 | 值 | 来源 |
|---|---|---|
| 面板 | `n12_42_02_0a_dsc_cmd_lcm_drv`，**DSC + DSI CMD**，1220×2712 | 设备 atag / DTB |
| framebuffer | `0xFD91F000`，size `0x026E0000`（末端 `0xFFFFF000`） | `/proc/device-tree/chosen/atag,videolfb*` |
| DSI 候选 | dsi0 `0x1420A000`、dsi1 `0x1420B000`、dsi2 `0x1420C000` | DTB |
| OVL 候选 | `0x14402000`/`0x14403000`/`0x14404000`（disp0 侧），`0x14602000...`（disp1 侧） | DTB aliases |
| MUTEX | `0x14001000`/`0x14201000`/`0x14401000`/`0x14601000` | DTB |
| 内核 | 6.1.57-android14-11（GKI） | vendor 模块 vermagic |
| 显示驱动 | `vendor_boot/lib/modules/mediatek-drm.ko`（6.08 MB，未 strip） | vendor_boot ramdisk |
| 面板/CMD 相关 | `panel-n12-42-02-0a-dsc-cmd.ko`、`vis_display.ko`、`mtk-cmdq-drv-ext.ko`、`cmdq-platform-mt6989.ko` | vendor_boot ramdisk |

## 2. 实验时间线

| 编号 | 内容 | 结果 |
|---|---|---|
| 01 | BootShim + 2MB UEFI FV，无显存映射 | 卡 logo（无输出） |
| 02 | 填 framebuffer 绿色 + 5s 后 PSCI 复位 | **不变色，正常复位** → 推帧缺失 |
| 03 | C 语言 payload 读显示寄存器 + 写日志 | 卡死（C 使用栈） |
| 04 | C 语言 payload 只写日志 | 卡死（确认根因是栈） |
| 05 | 纯汇编写 pstore + 填 fb + 复位 | 正常复位；expdb/pstore 未出现标记 |
| 06/08 | 纯汇编读 OVL/DSI/MUTEX + 写 pstore/log_store | 正常复位；标记仍未进 expdb |
| 10 | 填 fb → DSI0 `MODE_CTRL(0x14)=0` → `START(0x00)=0,1` → 5s | **不变色，正常复位** |

关键结论：
- LK 交接时 **SP 不可用**，任何使用栈的 C 代码都会卡死；payload 必须纯汇编、无 push/pop、无 C runtime。
- 读 `0x1420A000`、`0x14401000`、`0x1440202C` 不挂 → 这些显示 MMIO 页可访问。
- 单独 `DSI_START` 不能刷新 CMD 面板；CMD 面板需要完整的 OVL→DSC→DSI→MUTEX/CMDQ 触发链。
- 往 pstore（`0x48090000`）或 LK log_store（`0x63FFBE000`）写 ASCII 不会被下一次 preloader 搬进 expdb。

## 3. 厂商驱动资源

`vendor_boot` 的 ramdisk 里有完整显示模块（`lib/modules/mediatek-drm.ko` 等），已解出到：

```
work/modules/lib/modules/mediatek-drm.ko
work/modules/lib/modules/panel-n12-42-02-0a-dsc-cmd.ko
work/modules/lib/modules/vis_display.ko
work/modules/lib/modules/mtk-cmdq-drv-ext.ko
work/modules/lib/modules/cmdq-platform-mt6989.ko
```

`mediatek-drm.ko` 未 strip，符号完整，例如：

```
mtk_dsi_ddp_config, mtk_dsi_start_vdo_mode, mtk_dsi_cmdq, mtk_dsi_cmdq_gce,
mtk_dsi_cmdq_pack_gce, mtk_dsi_cmdq_poll, mtk_dsi_is_cmd_mode, mtk_dsi_poll_for_idle,
mtk_crtc_ddp_config, mtk_crtc_first_enable_ddp_config, mtk_crtc_comp_trigger,
_mtk_crtc_check_trigger, _mtk_crtc_cmdq_retrig, mtk_crtc_gce_flush,
mtk_drm_crtc_atomic_flush
```

## 4. 下一步

1. 用 OnePlusOSS 公开的 MT6989 vendor 源码（`android_kernel_modules_and_devicetree_oneplus_mt6989`）对照 `mediatek-drm.ko`，提取：
   - MT6989 的 OVL `driver_data`（真实寄存器偏移、layer 数、ADDR/PITCH 编码）；
   - DSI CMD 模式的 frame trigger / retrigger 路径（`mtk_crtc_comp_trigger`、`_mtk_crtc_cmdq_retrig`、`mtk_crtc_gce_flush`）；
   - DSC 参数与 `mtk_disp_dsc`/`mtk_dsc_wrap` 的配置；
   - MUTEX/SOF 与 GCE 事件表。
2. 反汇编 `panel-n12-42-02-0a-dsc-cmd.ko`，提取面板上电、DSC 参数、TE/窗口更新与 CMD 模式帧回调。
3. 在纯汇编 payload 中先做**只读快照**（不使用栈，不写显示寄存器），把 DSI/OVL/MUTEX/DSC/MMSYS 的值记录到可读回的位置；再按原厂序列最小化。
