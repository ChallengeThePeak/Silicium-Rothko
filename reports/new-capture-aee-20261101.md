# K70U 本次完整 expdb：AEE/ATF 容器审计

## 范围与结论

只检查 2026-11-01 11:06 这次捕获的原始文件，不操作设备、不修改源码、不重新构建镜像。

**本地字节确认：** 文件有一条 `kernel_sz=0x00048552`，即 296274 字节，与本轮新候选的压缩内核大小匹配；但没有可验证的 AEE 容器或 TFA 压缩数据，无法取得这次候选的异常 PC、ELR、FAR 或实时 WDT 阶段值。

这不是“候选没有运行”的证明。LK 的大小记录与 BootShim/SEC/DXE 的实际执行必须分别判断。

## 输入身份

- 文件：`I:\刷机\root\scrcpy-win64-v3.2\k70u-expdb-20261101-1106\expdb.raw.bin`
- 大小：134217728 字节。
- 独立重算 SHA-256：`dc179bf666686de63883b7370fa2346574a6240cff8f1949bcc3333c9015c12d`。
- 本审计不访问手机；设备采集、传输恢复及刷写时间线由主分析记录。

## 已确认的容器事实

| 检查 | 结果 |
|---|---|
| 开头 48 字节 AEE header | 12 个小端 32 位字段全部为零 |
| 开头 `0x2030` 字节 | 全零 |
| 完整文件内 `0xAEE0DEAD` | 小端、大端、ASCII 均无命中 |
| 完整文件内标准 gzip 头 `1f 8b 08` | 无命中 |
| 第一个非零字节 | `0x7e00000`，即前 126 MiB 全零 |
| 最后一个非零字节 | `0x7fff0f2` |
| 非零字节总数 | 2072316 |

已运行现有 `decode_aee_sections.py`。它按已知 AEE v18 的 48 字节头、64 字节 section record 验证规则，在入口拒绝该文件：

```text
No supported AEE v18 header; no current sections trusted
```

同时对完整文件搜索已知 AEE magic，未找到可继续验证的嵌套/环内候选。此结论限定为已知 AEE0DEAD 容器与标准 gzip，不宣称识别所有未知编码格式。

## 两处 TFA 名称不是有效压缩 section

- `0x7f7a5f3`：`kedump: start TFA_DEBUG_BUF.gz`
- `0x7f7a656`：`kedump add: TFA_DEBUG_BUF.gz[32] cf9/cf9@23a2898`

两处均为日志正文中的 kedump 进度文字。日志声称的 `0x23a2898` 起、`0xcf9` 字节数据，在本文件中**全部为零**。同样，`SYS_CUR_PLLK` 进度文字声称的 `0x2206529` 起、`0x246b0` 字节也全部为零。

因此不能凭名称提取一个“当前 TFA dump”，也不能借用旧捕获的压缩数据补成本次异常上下文。

## 正向标记与边界

- `0x7f53210`：`boot_linux_fdt:547: kernel_sz=0x00048552`，十进制 296274，匹配本轮新候选大小，不匹配旧 staged 的 296322。大小匹配不等于完整镜像哈希认证，也不单独证明执行已进入 UEFI。
- 另两条大小记录为 `0x015141fe`，不是上述候选大小；它们属于时间线分析的对照输入，本报告不按文件物理顺序擅自分配启动次序。
- 未找到 ATF 样式 `cpu(0) pc:`、`pstate=`、`esr_el` 或 `WDT LENGTH` 数据。
- 有 19 条 `[RGU] LENGTH:`，全部为 `0xFFE0`，上下文为 PL 初始化/复位状态记录，不是已验证 TFA section 中的实时寄存器快照；不能据此推断某个 UEFI 阶段未执行。
- 有 30 条 `[LASTPC]CPU0 pc=` latch 字段；部分伴随 `latch value may be corrupted` 提示。本审计不把这些值解码成当前 UEFI 的 PC。
- `0x7f7759d` / `0x7f775b9` 的日志文字分别给出 `panic_header.exp_type = 0x0`、`panic_header.wdt_status = 0x8004`。这是保留下来的文字元数据，不是文件开头已验证的 panic header；是否对应候选失败须由主分析的 PL/LK 时间线绑定。

## 阻塞与下一步

本捕获缺少有效 AEE/ATF payload，无法仅靠它定位当前候选的具体异常指令或 SEC/DXE 阶段。下一步只将 `0x7f53210` 的新候选大小记录与本次 flash/reboot/恢复原厂的时间线关联，不由缺失的异常 payload 引申其他失败原因。

## 留存证据

目录：`I:\刷机\root\scrcpy-win64-v3.2\k70u-expdb-20261101-1106\aee-audit-01\`

- `audit_capture.py`：输入大小/哈希固定校验，完整字节搜索；只创建新输出。
- `scan.json`：容器、gzip、寄存器文本、内核大小和零区检查结果。
- `contexts.txt`：有绝对字节偏移的匹配原文。
- `primary-parser.txt`：现有 AEE v18 parser 的命令、返回码和拒绝原因。

没有创建任何伪造或推测性恢复的 AEE section。
