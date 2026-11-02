# 真凶：DSI_BUSY 把第 3 帧之后全部丢弃（2026-11-02 17:27）

## 现象
屏幕冻结：黑底 + 顶部一条断续的绿色残影，菜单永远看不到。
但 pstore 证明一切都在正常跑：

```
ROTHKO: cleared 2 scanout layer(s) with the real pitch
K70U-BDS: RegisterKeyCallback -> Success
ROTHKO-KEYPAD: probe ... B(0x200)=0x8E30F909 bit4=0     ← 音量上按下了
K70U-BDS: EnterBootManager = 1
[Bds]Booting BootManagerMenuApp
（CreateFvBootOption 的三条失败消失了 → UniXNU 注册成功，菜单有条目了）
```

## 根因
`RothkoDisplayDxe` 的 `PushFrame()` 开头有一道门禁：

```c
#define DSI_INTSTA  0x00CU
#define DSI_BUSY    BIT31

if (MmioRead32 (DSI0_BASE + DSI_INTSTA) & DSI_BUSY) {
  return FALSE;          // 「上一帧还没传完，这一帧丢掉」
}
```

而日志里 INTSTA 的实际值：

```
ROTHKO: frame 1 submitted, dsi status=800A0004
ROTHKO: frame 2 submitted, dsi status=800B0016
```

**两帧的 bit31 都是 1**。第一帧推完之后它清了一次（所以第二帧过得去），
**第二帧之后再也没清过** → 从第三帧开始，每一帧都在入口被 `return FALSE` 丢掉。

`Refresh()` 里：

```c
if (!PushFrame ()) {
  return;                // 镜像都不做了，直接返回
}
```

所以 200 ms 的刷新节拍一直在跑、日志一直在写，但**没有一个字节到达面板**。
屏幕就死在第二帧那一刻的画面——正好是「清屏后的黑 + LK logo 顶部那条残影」。

## 修法
去掉 busy 门控，改成和厂商 `mtk_dsi_start()`、以及 LK 显示 logo 时完全一样的做法：
无条件 `write(0) → write(1)`。

```c
// [k70u 2026-11-02] Do NOT gate submission on DSI_BUSY.
// INTSTA bit31 reads back set right after the second frame on this panel and
// never clears...
```

同时加一条心跳日志，避免再出现「日志停在 refresh enabled、实际推帧已死」这种假阳性：

```
ROTHKO: refresh 25 frames, dsi status=........    (每 5 秒一条)
```

## 为什么之前几版"能亮但定住"
第一版点亮时看到的画面就是前两帧推出去的内容（诊断填充 + 少量日志行），
之后全部被 busy 门控挡掉。那时候以为是"静态画面不刷新"，实际是推帧根本没发生。
顶部那条断断续续的绿色，就是第二帧时刻帧缓冲里 LK logo 的顶部残影原样留在面板上。

## 产物

| 文件 | SHA-256 |
| --- | --- |
| `bringup/boot-k70u-uefi-menu4-20261102.img` | `e2c36c178199ac0e0ec9598569b9aba8915e003c6d5a0ba687af64274c4caa2b` |
| `bringup/init_boot-k70u-uefi-menu4-20261102.img` | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-menu4-20261102.fd` | `7bc1baf18fc363322dd67cb5a5854212f603cc7902245a9c23cec911cb2c25d5` |
