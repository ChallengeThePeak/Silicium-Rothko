# K70U 候选、yunluo UEFI 与原厂 boot.img 头部对照

| 项目 | K70U 候选 | yunluo 已知 UEFI Shell 镜像 | 原厂 K70U boot.img |
|---|---:|---:|---:|
| 文件大小 | 307,200 B | 67,108,864 B | 67,108,864 B |
| Android header | v4 / header 1584 | v4 / header 1584 | v4 / header 1584 |
| ramdisk | 0 | 0 | 0 |
| kernel 字段 | gzip | gzip | 原生 LZ4，首字节 `02 21 4c 18` |
| kernel_size | `0x4840b` | auto `0xc9412`；fixed6 `0xc8070` | `0xfc7fd7` |
| 解压后内容 | 192 B BootShim + 2 MiB FD | BootShim + 7 MiB FD | Linux kernel 内容 |
| ARM64 magic | offset 56 | offset 56 | 无 BootShim |
| signature 字段 | 4096 B 零签名区 | 0 | 0 |

## 判断

候选头部没有发现字段错位：`kernel_size` 等于实际 gzip 字节数，gzip 从
4 KiB 页边界开始，解压后是 192 B BootShim 加 2 MiB FV，BootShim 的
`text_offset=0x42000000`、`image_size=0x2000c0` 自洽。旧 K70U 的 31 号和
10 号 UEFI 镜像也使用同样的 v4/1584/零 ramdisk/4096 字节签名区布局。

yunluo 镜像的 BootShim 变体不同，FD 为 7 MiB；原厂 boot.img 则是 Linux
LZ4 kernel。两者都不能直接替换 K70U 候选的 FD/base/BootShim 组合。

`signature_size=4096` 是本地 `mkbootimg.py` 在 v4、未提供 GKI 签名时主动写入
的零签名区，不是 AVB `vbmeta` 分区本身。它和历史 K70U UEFI 镜像一致，单凭
这个差异不能解释当前失败；当前更强的证据仍是 expdb 没进入
`boot_linux_fdt`/`decompress kernel image`。

## DTB 入口修正（2026-10-31）

原候选虽然头部、gzip 和 FD 长度自洽，但其 192 B Shim 来自 `uefi-sheng`，
末尾直接 `br x5`。K70U MTK LK 的最终 trampoline 将 boot magic 放在 x0、DTB
放在 x2；K70U SEC 又把 x0 保存为 DTB HOB。因此仅看头部无法发现入口参数错误。
新的 `BootShim-rothko.S` 在 `br x5` 前写入 `x0=0x47c80000`，与 stock LK
`mb_dtb` 和候选内存图一致。新的 body/AVBf 产物与原候选头部参数相同，区别在
解压后 Shim 的最后一条路径。

完整静态解析来源：

- K70U 候选：`outputs/rothko-k70u-uefi-evidence-20261031.img`
- yunluo auto：`bringup/uefi/boot-yunluo-mu-auto-ram-ufs-v1.img`
- yunluo fixed6：`bringup/uefi/boot-yunluo-mu-6g-fixed-ufs-shell-v1.img`
- 原厂：用户提供的 OS3 `images/boot.img`


## AVB footer 补充核验（2026-10-31）

第三方 handoff-stage 的同平台构建器在 64 MiB boot 分区末尾写入 `AVBf`，其 AVB0
hash descriptor 为 424 B；其文档将无 footer 与 LK 的镜像表跳过联系起来。K70U
保存的分区表显示 `boot_a` 大小也是 `0x4000000`。因此从当前 307,200 B v4 body
生成了独立 64 MiB 变体：

- `work/evidence-20261031/boot-rothko-uefi-evidence-20261031-avbf.img`
- SHA-256 `2537c3b5e01b08f870dfb39a7a0836e04b24406352fdfb3b95a104be4d27a295`
- `AVBf` v1.0，`original_image_size=307200`，`vbmeta_size=424`，`digest_ok=True`

AVBf 变体保留原有 v4 header、gzip kernel 和 2 MiB FD，补的是容器尾部与分区填充。
这仍未验证顶层 `vbmeta_a` 链和设备实际启动；失败 expdb 的 home-key/fastboot 分支
发生在能否观察到该差异之前。
