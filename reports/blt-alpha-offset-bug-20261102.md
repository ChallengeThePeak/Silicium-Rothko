# 屏幕上方绿条 / 花的真凶：Blt 里 alpha 后处理的地址少乘 4（2026-11-02 17:34）

## 实锤（纯源码，无硬件假设）

`RothkoDisplayDxe.c` 的 `Blt()` 里，`FrameBufferBlt()` 之后有一段 alpha 后处理：

```c
Pixels = (UINT32 *)(VOID *)(UINTN)(mMode.FrameBufferBase +
         (UINT64)(DestinationY + Row) * mInfo.PixelsPerScanLine +
         (UINT64)DestinationX);

for (Col = 0; Col < Width; Col++) {
  Pixels[Col] |= 0xFF000000U;
}
```

`mMode.FrameBufferBase` 是**字节地址**，`Pixels` 是 `UINT32 *`，
所以行跨度和列偏移都**必须乘 `sizeof (UINT32)`**。

**写成 `Y * 1248 + X` 字节，实际只走到正确位置的 1/4。**

紧接着下面同一个函数里的 cache flush 写的是对的，两处一目了然：

```c
Pitch = (UINTN)mInfo.PixelsPerScanLine * sizeof (UINT32);          // ← 乘了 4
Start = mMode.FrameBufferBase +
        (UINT64)DestinationY * Pitch +
        (UINT64)DestinationX * sizeof (UINT32);
```

## 后果链

1. 每次 `Blt`（控制台画字、菜单画框、`SetMode` 清屏）都会把目标矩形的 alpha 位
   写到**屏幕高度 1/4 的位置**
2. 也就是说，整个屏幕的**上部 1/4 被每一帧反复写乱** —— 就是"屏幕上方出绿条"
3. 而且 `|= 0xFF000000U` 会把那个错误位置像素的整个高字节覆盖掉，
   连带改坏别人的 alpha/颜色 —— 就是"花、粉蓝绿"

这个 bug 从第一版移植就存在，所以之前每一版都能看到"顶部花"，
只是随后来推帧被 `DSI_BUSY` 卡死而变得更难分辨。

## 同时撤掉 BTSW

上一版为"红蓝互换"给每层加了 `L_CON_BTSW`。但：
- 这段 alpha 后处理**刻意把最高字节置 0xFF**
- BTSW 会反转整个 32 位字，把那个 0xFF 挪到红色通道
  （`0xFF000000` → `0x000000FF` = 红色且全透明）

反而更糟。菜单是黑/白/灰，红蓝顺序无关，所以恢复 LK 的设置。

## 修复

```c
Pixels = (UINT32 *)(VOID *)(UINTN)(mMode.FrameBufferBase +
         (UINT64)(DestinationY + Row) * mInfo.PixelsPerScanLine * sizeof (UINT32) +
         (UINT64)DestinationX * sizeof (UINT32));
```

## 产物

| 文件 | SHA-256 |
| --- | --- |
| `bringup/boot-k70u-uefi-bltfix-20261102.img` | `5fe560ee790b531b3228a9a05207659cc0a7ff8d87263a611ad352d9ece0eea1` |
| `bringup/init_boot-k70u-uefi-bltfix-20261102.img` | `933acc535d2fe935069346b041c31500acf2884a535694d9ae2b9dc3f0cbc853` |
| `bringup/SILICIUM_UEFI-bltfix-20261102.fd` | `3e2e5403086a6c807342e91308ca69184e70b1a7984d167274945244f4be97dd` |
