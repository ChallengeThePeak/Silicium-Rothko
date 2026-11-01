# 第三方 handoff-stage 的 boot 制作与 LK handoff 证据审阅（2026-10-31）

## 结论

**boot 制作思路值得借鉴，镜像版本/参数不应整套照搬。**可迁移的是把 BootShim+UEFI FD 压成 LK 接受的 kernel payload、明确 LK kernel load address 与 BootShim relocation 的区别、为产物生成 manifest/哈希并做独立解包验证。该包报告的成功镜像采用 Android boot header v0、`kernel_addr=0x40000000`、4096 page、gzip 的 Shim+FD，FAT payload 放在 boot ramdisk，并附 AVBf/hash descriptor。

K70U 当前候选使用 v4、零 ramdisk、gzip 的 Shim+2 MiB FD，且 BootShim relocation 到 `0x42000000`；K70U stock LK 的正常 `/proc/pl_lk` 已实证 v4 路径会加载 boot/vendor_boot/init_boot、从 vendor_boot/DTBO 取得运行时 DTB，随后解压并跳到 `0x40000000`。因此 v0 的主要动机（legacy 路径自带 ramdisk/DTB，避免 v4 切换 vendor_boot ramdisk）对当前“只验证 UEFI handoff”的 K70U 镜像并非自动适用。

## “boot to linux”是否是幻觉

这份材料不像凭空编造：`docs/hardware/lk-kernel-load-path.md` 给出了原 expdb 的文件偏移 `132,216,611`、五个重复 block、原始 panic 行和一段完整成功序列，包括 `kernel_sz`、`decompress kernel image`、`booting linux @ 0x40000000`、`lk finished --> jump to linux kernel 64Bit`；另外文档把早期失败 r6（`0x40008000` 未满足 512 KiB 对齐）与之后成功配置区分开，内部逻辑连贯。

但 handoff-stage 不含 `blackbox_r8.img` / `expdb_r8.img` 原始文件，也没有保存能直接复核那段 L1 成功日志的原始导出。因此这是**具体、可信度中高的二手证据，尚非独立复核**。`lk finished --> jump...` 是 LK 进入 EL 切换 trampoline 前的日志，强力支持 LK 已完成 Linux image 处理并准备跳转；它单独不能证明下一条指令确实进入 BootShim，更不能证明 UEFI 已执行。文档所谓 L2（约 12 秒后 PSCI reset）若有原始 pstore/expdb marker 支撑会进一步加强，但本 handoff 包未包含相应现场字节，故不把它算作本次独立确认。

同时，包内 `MANIFEST.sha256` 所列 14 个镜像/构建产物均与实际 SHA-256 一致，证明包内二进制与该 handoff manifest 一致；这不等于证明设备曾运行这些镜像。

## 哪些 boot 制作做法可迁移

| 做法 | 建议 | 理由 |
|---|---|---|
| gzip(kernel slot) = BootShim + FD；BootShim 再搬运/进入目标 FD | 借鉴 | 符合 LK 按 kernel 字段解压的执行模型；K70U 候选已采用，需保留对实际解压内容、长度和入口的逐字节检查。 |
| 分开记录 LK 解压地址与 UEFI FD relocation 地址 | 借鉴 | K70U stock LK 交接地址为 `0x40000000`；候选 FD base `0x42000000` 是 BootShim 的后续目标，二者不能混为 header 的 kernel_addr。 |
| 生成镜像 JSON、hash、可重复打包及独立解析 | 借鉴 | 第三方包的 p4a JSON 和 manifest 是很好的交付形式；可以让候选报告直接记录 header、gzip 解包、BootShim 字段、FD hash、AVB footer/分区长度。 |
| v0 + boot ramdisk 内放 FAT payload | 当前不迁移 | 这是它加载 UniXNU payload 的路线；K70U 当前实验目标是先证明 UEFI handoff，候选 v4 的零 ramdisk 可避免无必要改动 vendor_boot/init_boot 行为。若未来 LK/UEFI 阶段确实要读取 FAT payload，再单独设计并验证。 |
| v0 自带 DTB / kernel 尾部追加运行时 DTB | 不迁移到当前镜像 | 第三方明确这是 legacy LK 路径专用。K70U 的正常 v4 分支已有原厂 vendor_boot DTB + DTBO 路径；在 kernel gzip 尾部追加 DTB可能触发 LK 的尾部扫描/DTB 选择副作用。 |
| AVBf footer/hash descriptor | **已落成独立 K70U 变体，优先实机验证** | 第三方源码的 `avb_footer.py` 生成了规范 AVB0 hash descriptor（424 B）和 AVBf v1.0；其构建文档还记录无 footer 时 LK 跳过已加载镜像表。基于 K70U `boot_a=0x4000000` 的分区大小，已对当前候选原始 body 生成 64 MiB AVBf 变体并离线验证 digest。K70U 正常日志虽然有 `vbmeta_a HASH_MISMATCH`，之后却明确 `img_auth_required=0`、`avb_ret=0` 并正常解压/跳转；这说明 mismatch 不是正常 stock boot 的阻断点，但不能据此排除自制 boot 缺 footer。 |
| 64 MiB 固定分区尺寸与刷 boot_a | 不迁移为构建硬编码 | 它是 rothko 分区/fastboot 实验约定。K70U 候选当前仅 307,200 B，必须进一步确认实际写入/AVB footer 语义与分区大小关系；当前失败现场未进入 boot image 解析，尚不能用启动失败确认或排除这一点。 |

## 对 K70U 当前失败的影响

失败 expdb 的两组序列都记录 home key pressed / `boot_reason=1` / `notify_enter_fastboot`，随后仅到 `wait_for_boot_linux`；正常 `/proc/pl_lk` 也共享 fastboot app 和 wait 前缀，但接着有 `Ready to boot linux...`、header loaded 和 `boot_linux_fdt`。因此这两次失败**没有测试出候选 boot header 或 AVB footer 是否被 LK 接受**。不应因为第三方镜像成功就立即把 K70U 候选切到 v0，也不应据此认定当前 v4 封装无问题。

## 后续可验证项（离线，不刷机）

1. 对 K70U 候选和历史 UEFI 镜像逐字节解析完整 Android header，记录 `kernel_size`、`ramdisk_size`、`kernel_addr`、`header_version`、`signature_size`、gzip 起始偏移及文件末端 AVBf/vbmeta 情况。
2. 从 K70U stock LK 反编译确认 boot 分区读取长度、AVB footer/vbmeta 探测与 v4 header 的真实分支；正常 `/proc/pl_lk` 的 `avb_ret=0` 只能作为执行结果旁证。
3. 任何需要重新判定刷入候选的结论，都要先看到本次启动确实离开 fastboot 事件等待并进入 `Ready to boot linux...` / header loaded；当下禁止代理写设备，待用户自行决定设备测试安排。
4. 若能拿到第三方原始 `blackbox_r8` 或 expdb 导出，再验证其候选镜像标记、LK 行、boot index/slot 与后续 PSCI/pstore 证据是否同一启动。

## 来源

- 第三方：`D:/漏洞/rothko-unixnu-handoff-20261025/handoff-stage/README-HANDOFF.md`、其 `docs/hardware/lk-kernel-load-path.md`、`docs/hardware/lk-bootimg-path.md`、`docs/bring-up/stage1-flash-runbook.md`、`firmware-build/p4a-boot.json`、`MANIFEST.sha256`。
- K70U：`reports/boot-header-comparison-20261031.md`、`reports/evidence-20261031-stock-lk.md`、`reports/expdb-lk-handoff-20261031.md`、`work/evidence-20261031/logs/proc-pl_lk-normal-20261031.txt`、`work/evidence-20261031/logs/device-expdb-full-after-flash-20261031.bin`。


## 已生成的 AVBf 候选

第三方 helper 已以独立脚本形式放入 K70U evidence overlay：
`src/uefi-rothko-evidence-20261031/scripts/avb_footer.py`，调用包装器为
`add-avb-footer.py`。它不覆盖原始候选，而是把现有 307,200 B body 填充到 K70U
`boot_a` 的 64 MiB 分区，并在末尾追加 AVB0/AVBf。

产物：

- `work/evidence-20261031/boot-rothko-uefi-evidence-20261031-avbf.img`
- SHA-256：`2537c3b5e01b08f870dfb39a7a0836e04b24406352fdfb3b95a104be4d27a295`
- `AVBf` v1.0，`original_image_size=307200`，`vbmeta_size=424`，algorithm NONE
- 独立 verify：`digest_ok=True`；gzip 解压后 `2,097,344` B，BootShim magic `ARMd`
- 对应清单：`work/evidence-20261031/boot-rothko-uefi-evidence-20261031-avbf.json`

这个变体只修正镜像容器层，不能解决失败现场的 home-key/fastboot 事件分支，也没有经过设备启动。


## 用户修正后的证据边界

不把 expdb 中的 home-key/fastboot 段当作本次 UEFI 失败的主因。它们是环形 expdb 中的 LK 历史文本，不能单独证明候选 UEFI 未执行；LK patch dry-run 不纳入可用方案。当前可交付修正仍是 UEFI 固件 + AVBf boot 容器 + 低校验 vbmeta 的离线组合。
