# 菜单已启动，按键布局改为运行时探测（2026-11-02 17:13）

## 一、pstore 实锤：菜单确实起来了

```
Loading driver ... GpioDxe.efi
Loading driver ... KeypadDeviceDxe.efi
ROTHKO-KEYPAD: no PMIC protocol (Not Found), only Volume Up available
ROTHKO-KEYPAD: Volume Up = GPIO 196 (active low), PMIC keys unavailable
Loading driver ... BdsDxe.efi
Loading driver ... SetupBrowser.efi
Loading driver ... KeypadDxe.efi
PlatformBootManagerAfterConsole: Failed to Display Boot Logo! Status = Not Found
[Bds]Booting BootManagerMenuApp
Loading driver ... BootManagerMenuApp.efi
```

`BdsEntry` 的提前 `CpuDeadLoop` 删除后，BDS 正常走到
`PlatformBootManagerPriorityBoot` → BootOrder 为空 → 自动进菜单。
pstore 里有两份完整启动记录（环形缓冲保留了一次旧的，第 4 行与第 438 行各有一个 banner）。

顺带确认：`DisplayBootGraphic - Failed to find BootLogo2 Protocol`，所以屏幕上的图形
不是 UEFI BootLogo（`Extra.fdf.inc` 里的 `BootLogo.bmp` 与本轮无关，未加入）。

## 二、按键没反应的原因：GPIO 寄存器布局从未在 MT6989 上验证

树里唯一的 MTK GPIO 布局来自 `MT6789Pkg`：

```
dir 0x000 / dout 0x100 / din 0x200 / mode 0x300
```

但这台设备实际用的是 Linux `pinctrl-mtk-common-v2`（dmesg：
`10005000.pinctrl: mtk_eint_do_init`，debugfs 节点 `10005000.pinctrl-pinctrl_mtk_v2`），
它的布局是：

```
mode 0x000 / dir 0x400 / dout 0x500 / din 0x600
```

两套完全不同，而 `MT6789Pkg` 那份在本平台从未执行过。

### 设备侧已实锤的部分
```
/sys/kernel/debug/pinctrl/10005000.pinctrl-pinctrl_mtk_v2/pinconf-pins
pin 196 (GPIO196): input bias pull up (101 ohms), output drive strength (0 mA),
                   input enabled, input schmitt enabled, output enabled
```
pin 196 是**整张 pinconf 表里唯一被上拉的引脚**，与 DTBO
`gpios = <&pio 0xC4 0x1>` 完全一致 → 音量上 = GPIO 196 无疑。
（`/dev/mem` 在本机不可用，`devmem` 读不了物理地址，所以偏移只能靠运行时判定。）

## 三、这版怎么做：双布局运行时锁定

不再依赖 `GpioDxe` 协议，`KeypadDeviceLib` 直接读 pinctrl 的 data-in 块，
同时采样两套候选寄存器：

```
A) busy v2 : 0x10005000 + 0x600 + (196/32)*0x10 = 0x10005660, bit 4
B) legacy  : 0x10005000 + 0x200 + (196/32)*0x10 = 0x10005260, bit 4
```

上拉保证**只有真正接到 pin 196 的寄存器在空闲时读到 1**，另一套要么是无关块、
要么是未实现的偏移（读 0）。于是：

1. 构造时读两套的 idle 值；若**恰好一个读到 1**，直接锁定它；
2. 否则等按键：只有 `idle==1` 且读回 0 的那套才会被锁定（避免被恒 0 的假寄存器抢走）。

锁定后日志打印一次：`ROTHKO-KEYPAD: locked <layout> ...`。

同时修了两处手感问题：
- 按下**立即上报**（原来要等 500 ms 重复阈值或松手才报，菜单像死机）；
- 长按 500 ms 后每 100 ms 自动重复。

## 四、这版新增的诊断（一次性，10 次自停）

```
K70U-BDS: RegisterKeyCallback -> <status>
K70U-BDS: EnterBootManager = 0/1
ROTHKO-KEYPAD: pin 196 idle din: A(0x600)=0x........ bit4=?  B(0x200)=0x........ bit4=?
ROTHKO-KEYPAD: probe A(0x600)=... B(0x200)=... locked=...
```
`probe` 每 2 秒打一次、最多 10 次（约 20 秒），刷一次机就能同时回答：
- notify 有没有注册成功
- 哪套布局是真身
- 按住音量上时该寄存器的实际值

## 五、未解决：顶部绿色方块

屏幕顶部有“一行 5 格绿色区域”，其余正常。已排除的因素：
- GOP `format=1` = `PixelBlueGreenRedReserved8BitPerColor`，与面板 XB24 内存序一致
- 扫描层 2 个（L0 帧缓冲 pitch 4992、L1 LK UI 层 pitch 4880），驱动每帧镜像
- `DisplayBootGraphic` 失败，所以不是 UEFI BootLogo

待定方向（需要截图确认位置与数量对应什么）：
1. LK 的 L1 图层顶部残留未被完全覆盖
2. 帧缓冲日志（`FrameBufferSerialPortLib` 直接写屏）与 GOP 菜单抢同一块内存
3. 面板 DSC 顶部 slice 边界

## 六、产物

| 文件 | SHA-256 |
| --- | --- |
| `bringup/boot-k70u-uefi-keypad2-20261102.img` | `bfaa1225742e08c89a05ac431ef6422cc3768edbdd6446ed631b316a3087ed35` |
| `bringup/init_boot-k70u-uefi-keypad2-20261102.img` | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-keypad2-20261102.fd` | `896637d21139cb1b2cc138f4f959b5b0437d81d6c0b07580c8ad1456247e8a9f` |
