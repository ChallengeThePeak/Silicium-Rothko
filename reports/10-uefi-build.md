# 10 — rothko UEFI 构建记录

日期：2026-10-22
工作区：`D:\漏洞\UNIXNU\适配K70U`

## 构建输入

| 项 | 值 |
|---|---|
| Mu-Silicium | `42fe563791e51bf5500c2e470ed294ca0c94b97c` |
| 板级包 | `src/uefi-rothko/Platforms/Xiaomi/rothkoPkg` |
| SoC 包 | `src/uefi-rothko/Silicon/MediaTek/MT6989Pkg` |
| 配置 | `src/uefi-rothko/Resources/Configs/rothko.toml` |
| 工具链 | WSL Ubuntu 24.04，clang 18.1.3，EDK II CLANGPDB，python 3.12 |
| 构建脚本 | `src/uefi-rothko/scripts/build-uefi-rothko.sh` |
| 打包脚本 | `src/uefi-rothko/scripts/pack-bootimg-rothko.py` |

## 构建命令（脚本内）

```bash
export WORKSPACE=<Mu-Silicium>
export EDK_TOOLS_PATH=<Mu-Silicium>/Mu_Basecore/BaseTools
export PACKAGES_PATH=<Mu-Silicium>:...:Silicon/MediaTek:Silicon/Silicium
build -p rothkoPkg/rothko.dsc -a AARCH64 -b DEBUG -t CLANGPDB \
  -D FD_BASE=0x42000000 -D FD_SIZE=0x200000 -D FD_BLOCKS=0x200 \
  -D ENABLE_SECUREBOOT=0 -D MEMORY_PROTECTION=TRUE -D SHIP_MODE=FALSE
```

结果：`build rc=0`，耗时 3 分 02 秒。

## 产物

| 文件 | 大小 | SHA-256 |
|---|---|---|
| `SILICIUM_UEFI.fd`（20:03 重编） | 2,097,152 | `14B557573109E9AC4EDF0924334B04927C37D12AEA2EC4D8DF07B9C0FC1B4EE9` |
| `bringup/boot-rothko-uefi-01.img`（无显存映射） | 311,296 | `F0B0EC96A0ACD04BF3285FA76D6787119420C31836C75D157187E1CC232A90BB` |
| `bringup/boot-rothko-uefi-02.img`（含运行时显存） | 311,296 | `4F926E4520F224C819A27E481002ECAFA0EB7173AFA03B2366B7472895DDFF19` |

## 运行时显存参数（设备实测，2026-10-22）

在已 root 的 rothko 上读取（只读）：

| 属性 | 值 |
|---|---|
| `/proc/device-tree/chosen/atag,videolfb-fb_base_l` | `0xFD91F000` |
| `atag,videolfb-fb_base_h` | `0x00000000` |
| `atag,videolfb-vramSize` | `0x026E0000` |
| `atag,videolfb` 原始 blob | fb_base=0xFD91F000（LE u64），lcm 名 `n12_42_02_0a_dsc_cmd_lcm_drv` |
| DRM `card0-DSI-1/modes` | `1220x2712` |
| MemTotal | 23,704,396 kB（24 GB 版本） |

自洽校验：`0xFD91F000 + 0x026E0000 = 0xFFFFF000`，显存 carveout 正好结束在 4 GiB 边界下 4 KiB。

boot image 结构（已校验）：

- `ANDROID!`，header v4，page 4096，cmdline `bootopt=64S3,32N2,64N2`
- kernel field = gzip(192 B BootShim + 2 MiB FV)，gzip 大小 0x4920B
- 解压后 0x2000C0 字节，ARM64 header `text_offset=0x42000000`、`image_size=0x2000C0`
- 无 ramdisk（第一轮只跑固件，不加载 UniXNU payload）

## 尚未确认的输入

1. **运行时 framebuffer 基址**（`ROTHKO_DISPLAY_BASE`）：静态 DTB 里没有，LK 运行时才写入。
   当前 `MemoryMapLib.c` 里为 0，表示不映射、不写显存；UEFI 能启动但屏幕不会有输出。
2. 面板实际 pitch（暂按 `pitch == width = 1220`）。
3. LK 是否接受 `fastboot boot` 这个 boot image（需上机验证）。

## 复现

```bash
# Windows 侧
wsl -d Ubuntu2404 -- bash -lc 'bash "/mnt/d/漏洞/UNIXNU/适配K70U/src/uefi-rothko/scripts/build-uefi-rothko.sh"'
wsl -d Ubuntu2404 -- bash -lc 'python3 "/mnt/d/漏洞/UNIXNU/适配K70U/src/uefi-rothko/scripts/pack-bootimg-rothko.py"'
```
