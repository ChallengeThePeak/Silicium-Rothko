# 待下载文件交接单（K70U UEFI 构建）

日期：2026-11-02
用途：Xiaomi Redmi K70 Ultra（rothko / MT6989）UEFI 固件编译的最后一个缺失依赖

---

## 一句话需求

**只需要下载 1 个文件**，放到指定目录，回传哈希即可。其余依赖、仓库、工具链全部已就绪。

---

## 必须下载的文件

| 项 | 值 |
| --- | --- |
| 文件名 | `mu_nasm.20016.1.1.nupkg` |
| 版本 | 20016.1.1 |
| 格式 | NuGet 包（本质是 zip） |
| 用途 | EDK2 构建时提供 NASM 汇编器，Mu 项目私有 feed 包 |

### 首选下载地址（Project Mu 官方 Azure DevOps feed）

```
https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/flat2/mu_nasm/20016.1.1/mu_nasm.20016.1.1.nupkg
```

如果返回 404，用 feed 索引自己拼地址：

```
https://pkgs.dev.azure.com/projectmu/mu/_packaging/Basetools-Binary/nuget/v3/index.json
```

在返回的 JSON 里找 `"PackageBaseAddress/3.0.0"` 的 `@id` 值，然后拼：

```
<PackageBaseAddress>/mu_nasm/20016.1.1/mu_nasm.20016.1.1.nupkg
```

### 备用地址（nuget.org 公共源，未必有这个包）

```
https://api.nuget.org/v3-flatcontainer/mu_nasm/20016.1.1/mu_nasm.20016.1.1.nupkg
https://www.nuget.org/api/v2/package/mu_nasm/20016.1.1
```

> 说明：`mu_nasm` 是 Microsoft Project Mu 为 EDK2 构建发布的包，源在 Azure DevOps 私有 feed，
> nuget.org 上不保证存在。**优先用 Azure 那条。**

---

## 存放位置

```
D:\漏洞\UNIXNU\适配K70U\downloads\mu_nasm.20016.1.1.nupkg
```

要求：

- 文件名保持原样，**不要改名**
- **不要解压**
- 目录不存在就新建 `downloads`

---

## 校验方法

1. 文件应是 ZIP 格式（`.nupkg` 就是 zip），用压缩软件能打开，里面应能看到 `mu_nasm.nuspec`
2. 大小正常在 1–20 MB 区间（不是 0 字节、不是 HTML 错误页）
3. 计算哈希并回传：

```powershell
Get-FileHash .\mu_nasm.20016.1.1.nupkg -Algorithm SHA256
```

---

## 已经就绪、不要重复下载的东西

| 依赖 | 状态 |
| --- | --- |
| `Mu-Basetools` v2026080000.0.0-rc0 | 已落地 `Mu_Basecore/BaseTools/Bin/Mu-Basetools_extdep/Linux-x86` |
| `OneCrypto-Accelerated` 1.1.2 | 已落地 `Mu_Basecore/CryptoPkg/Binaries/onecrypto-bin_extdep` |
| `NuGet.exe` 6.4.0 | 已下载并校验，SHA256 `26730829b240581a3e6a4e276b9ace088930032df0c680d5591beccf6452374e` |
| WSL 内 mono 6.8 | 已本地解包安装（无 root） |
| EDK2 构建 Python 依赖 | 已安装（edk2-pytool-extensions 0.31.3） |
| 源码仓库 | 主仓 `main`、`uefi/rothko` 全量、三个子模块（Mu_Basecore / Silicium-ACPI / openssl）均已克隆 |

---

## 背景（可直接转述给对方）

> 在编译 Xiaomi K70 Ultra 的 UEFI 固件。EDK2 的 `stuart_update` 在构建前会强制校验一个
> 名为 `mu_nasm` 的 NuGet 包，它托管在 Microsoft Project Mu 的 Azure DevOps 私有 feed 上。
> 当前网络访问该 feed 直接失败（curl 返回 000，无法建连），导致整个固件卷（FD）编不出来。
> 源码、工具链、mono、其余两个外部依赖都已经准备好，只差这一个几 MB 的包。

---

## 拿到之后我会做什么

1. 把包解到 WSL 的 NuGet 全局缓存 `~/.nuget/packages/mu_nasm/20016.1.1/`
2. 重跑 `Platforms/Xiaomi/rothkoPkg/DeviceBuild.py --update`，让 `stuart` 从本地缓存命中（不走网络）
3. 编译 `SILICIUM_UEFI.fd`（DEBUG，2 MiB，FD_BASE=0x40400000）
4. 用上游 `tools/boot_v4.py` 打包 `boot`（LZ4(BootShim+FD)）与 `init_boot`（1 MiB FAT），保留 stock AVB 尾部
5. 输出镜像 + 校验报告

**如果对方有可用的代理/VPN，直接给一个能连 `pkgs.dev.azure.com` 的代理也行**，效果等同。
