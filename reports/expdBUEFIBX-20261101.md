# expdBUEFIBX 检查结果（2026-11-01）

## 已实测：输入格式

- 用户文件：`C:/Users/Administrator/Pictures/expdBUEFIBX`。
- 大小：640127 B，15193 行，全部为 ASCII，无 NUL、无标准 gzip 头。
- SHA-256：`64b99def629190411549dc9b6b22af63a7833ad756530ffff2b59b8c163440db`。
- 这是文本导出，不是 134217728 B 的完整 expdb 原始分区。
- 原文件未改；副本与机器可读分析在 `work/expdBUEFIBX-20261101/analysis-01/`。

## 已实测：保留了什么

| 内容 | 本文件记录 |
| --- | --- |
| boot_a 刷写 | 第 5575、14324 行 |
| 重启请求 | 第 5627、14376 行 |
| 第一处刷写后相邻文本 | 第 5628–6444 行，末尾是 early_save_pllog 保存边界 |
| 第二处刷写后相邻文本 | 第 14377–15193 行，末尾同样是日志保存边界 |
| 文本片段 | 7 个，不等于 7 次独立启动 |
| 重复前缀 | 片段 5、6 的 813 行逐字节相同 |
| LK mt_boot / wait | 各 2 处 |

重复前缀 SHA-256：`f4f2b2cdb34417b2916d121bc169ec78f2f6b744d306269a3f26d9886a77a312`。
两个刷写后的文本切片分别保存在 `flash-01-adjacent-text.txt` 和 `flash-02-adjacent-text.txt`。
这些编号表示文本邻接关系，不是已经验证的整圈日志时间线。

## 没有足够证据的内容

本文件没有：

- fvfix 的 `kernel_sz=0x00049fba`，也没有其他 kernel_size。
- Ready、boot header/decompression 或最终跳转记录。
- BootShim/SEC/DXE 标记、有效 ATF PC、PSTATE、ESR/FAR 或 TFA payload。

因此无法仅凭此文件把某个异常或停点绑定到新 fvfix 镜像。
64 MiB download 和 flash 命令不包含镜像内容哈希，不能代替运行身份。
PL 的 `LENGTH=0xFFE0`、`LASTPC` 原始 latch、early-save 末行都不能充当 UEFI fault PC。

**不能因此推断候选没加载、UEFI没执行、又卡在 preloader，或者把以前的 AEE 当成本次异常。**
此前匹配旧 keepalive 候选的 LK 加载证据仍然成立；本文件只是没有提供新版的充分运行证据。

本文件不含原始分区的二进制区域，因此也不能判断这次 raw 的 AEE 区是否仍有内容。
上一份 raw 前 126 MiB 全零的观察不适用于这个新输入。

## 下一步与本轮边界

继续定位需要这次测试对应的完整 raw expdb，而非 strings 文本；尤其需要保留压缩 AEE/ATF
区域、原始字节偏移及日志头。若 raw 也没有异常 payload，再选择新的 UEFI 现场取证手段。
在取得正向证据前，不盲改 GIC、Timer、BootShim、preloader 或 NoGZ 相关设置。

本轮仅分析用户文件，没有访问手机、重编固件或写入设备。
