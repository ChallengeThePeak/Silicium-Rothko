# K70U UEFI 移植工作区（Redmi K70 Ultra / MT6989）

本目录记录把 **Silicium-Rothko** 上游 UEFI 移植到 Xiaomi Redmi K70 Ultra
（代号 `rothko`，MT6989）的全过程：**分析报告、构建脚本、实机证据与结论**。

固件源码本体不在本目录，在 WSL 侧：
`/home/ubuntu/rothko-upstream-20261102/uefi-full`（上游 `uefi/rothko` 分支）。

## 当前状态（2026-11-02）

UEFI 已**完整启动到 BDS**：21 个 DXE 驱动装载完毕、GCD 初始化通过、
无异常无断言。BDS 阶段因平台尚无启动项而停住，等待看门狗复位。

pstore 日志已验证可读（`/sys/fs/pstore/pmsg-ramoops-0`）。

## 目录

| 路径 | 内容 |
| --- | --- |
| `reports/` | 每一轮的实机分析报告（崩溃定位、内存图、调度顺序、日志链路等） |
| `scripts/` | 构建与取证脚本（WSL 构建、打包、日志解析、expdb/blackbox 扫描） |
| `.planning/` | 任务计划与进度记录 |
| `.workbuddy/memory/` | 项目长期记忆与每日工作日志 |
| `bringup/` | 可刷写镜像输出（**不入库**，见 `.gitignore`） |

## 构建与刷写

```bash
# 构建（官方链：DeviceBuild.py + stuart）
bash scripts/wsl-final-build-20261102.sh

# 打包（上游 tools/boot_v4.py，legacy LZ4 + 保留 AVB 尾）
bash scripts/wsl-pack-label-20261102.sh <标签>
```

产物固定两个：

```
fastboot flash boot     "D:\漏洞\UNIXNU\适配K70U\bringup\boot-k70u-uefi-<标签>.img"
fastboot flash init_boot "D:\漏洞\UNIXNU\适配K70U\bringup\init_boot-k70u-uefi-<标签>.img"
fastboot reboot
```

## 取日志

固件日志只存在于 DRAM 的 pstore 区（`0x48090000` 起 `0xE0000`），
`expdb` / `blackbox` / `pstore` 分区里都没有。

```bash
adb shell su -c "cp /sys/fs/pstore/pmsg-ramoops-0 /sdcard/pmsg.bin"
adb pull /sdcard/pmsg.bin logs/pmsg.bin
python scripts/parse-pmsg.py
```

**注意**：PSCI 复位在这台机器上等价冷启动，会清掉 DRAM；只有看门狗超时复位能保住日志。

## 相对上游的固件改动（共 6 处）

1. `MemoryMapLib.c`：资源描述符属性 `SYS_MEM_CAP_XN` → `SYS_MEM_TESTED`
   （`Gcd.c` 要求掩码后恰好等于 `PRESENT|INITIALIZED|TESTED`）
2. `MemoryMapLib.c`：内存表裁到 3 GiB（3–4 GiB 段访问触发 address size fault）
3. `FrameBufferSerialPortLib.c`：`FbRegion` 未初始化 + 越界缓存刷新
4. `APRIORI.inc`：移出 `BdsDxe`（APRIORI 优先调度，会早于 `HiiDatabaseDxe`）
5. `rothko.dsc`：`PcdDriverHealthConfigureForm` 置零，跳过驱动健康检查
6. `UniXNUConfig.dsc.inc`：注释两条未在任何 DEC 声明的 PCD（EDK2 error F001）

## 许可

上游 `ChallengeThePeak/Silicium-Rothko` 为私有仓库，本工作区内容随其许可。
