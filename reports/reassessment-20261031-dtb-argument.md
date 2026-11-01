# K70U 重新评估：BootShim DTB 参数错误

## 结论

上一轮刷入的 AVBf boot 和 flags=3 vbmeta 只修正了容器校验层，仍然使用了
`D:\\漏洞\\UNIXNU\\src\\uefi-sheng\\BootShim\\BootShim.S` 的通用 192 字节
Shim。这个 Shim 最后直接 `br x5`，保留 LK 进入镜像时的 `x0`。

因此“刷了 AVBf/低校验仍然无效”与这次重评估是一致的：那一轮实际上没有
改变 UEFI 入口参数，不能用来否定 UEFI 固件内部的 GIC/内存/显示修正。

K70U OS3 stock LK 的最终跳转参数已由反汇编固定下来：

```text
x0 = 0xC2000115       boot magic
x1 = 0x40000000       mb_kernel / kernel entry
x2 = 0x47C80000       mb_dtb / merged DTB
x3 = 0
```

LK 的跳转包装器把这四个值传给 kernel entry。当前候选 UEFI 的
`ModuleEntryPoint.S` 保存 x0 到 `gSecEntryArg0`，`Sec.c` 再把它写入
`gSiliciumEntryArgHobGuid`，DXE 从该 HOB 读取 DTB。也就是说，旧 Shim 让
UEFI 把 `0xC2000115` 当成 DTB 地址，DTB 解析必然失败；GIC、显示和 watchdog
修正不会在这个入口参数错误之前生效。

第三方 rothko Shim 的末尾已经有同样的设备特化动作：
`ldr x0, =0x47C80000; br x5`。这与 K70U 的 stock LK reserved-memory 记录和
候选 `MemoryMapLib.c` 的 `LK DTB` 区域一致。

## 新产物

新 Shim 源码为 `src/uefi-rothko-evidence-20261031/scripts/BootShim-rothko.S`，
只增加 DTB 参数修正，保留原 2 MiB FD 和 v4 Android boot 结构。已生成：

| 产物 | 大小 | SHA-256 |
|---|---:|---|
| `work/evidence-20261031/boot-rothko-uefi-evidence-20261031-dtbfix-body.img` | 307200 B | `4181600fa31f7007e53510d08aa7f5ccb892f81c9a3b5a8e2cc7526d1f8ffe23` |
| `work/evidence-20261031/boot-rothko-uefi-evidence-20261031-dtbfix-avbf.img` | 67108864 B | `41b2279af185232c22fcce61d83d764f4abd21f1df7c760f716cfd10c638de68` |

离线验证均通过 Android v4、gzip、ARM64 header、`FD_BASE=0x42000000`、
2 MiB FD 回读；AVBf 的 424 B hash descriptor 也通过 digest 校验。验证器已修正为
按 Android header 的 `kernel_size` 截断 gzip，这样不会把分区末尾的 AVBf footer
误当作 gzip 数据。

## 证据边界

这是一个由 stock LK 反汇编和当前 UEFI SEC 代码共同推出的确定性入口修正，
比“再换 AVB footer”更直接。设备当前未连接，本轮没有刷写或启动；仍需一次
用户控制的 `boot_a` 测试和同轮 expdb/pstore 才能证明 DTB HOB、SEC、DXE 已运行。


## Correction after tracing the SMC boundary
The previous claim that kernel entry receives x0=0xC2000115 is withdrawn.
Stock LK loc_507118B4 executes `mov x4,#1; smc #0; ret`: the
0xC2000115 value is an SMC function ID, not proven kernel-entry data.
Stock tee.img contains its registration at ATF payload offset 0x72d08,
with handler pointer 0x4880ca28. Handler payload offset 0xca28 saves
arguments and calls 0xc2f0 to construct the nonsecure entry context.
At 0xc2f0 the 64-bit branch writes entry PC, SPSR (0x3c5 or 0x3c9),
and argument fields, so LK call-site registers cannot be equated to final
kernel-entry registers. Full dispatcher-to-context argument mapping remains
to be checked before claiming a DTB defect. The generated dtbfix images are
experimental comparison artifacts, NOT a demonstrated root-cause fix.
No device writes or boots were performed. Continue with the ATF context
mapping and then add same-boot diagnostic evidence if necessary.


## ATF audit final correction (supersedes DTB-fix hypothesis)
Saved instruction evidence: work/evidence-20261031/stock-lk/atf-smc-handoff-audit-20261031.json.
The SMC dispatcher at payload 0x2c318 captures x1 in x23 and x2 in x21;
at 0x2cafc it calls the registered handler with x0=x23, x1=x21.
Registration at 0x72d00 points SMC 0xC2000115 to handler 0x4880ca28.
For x3=1 (LK sets x4=1 before SMC), handler stores kernel as entry PC,
DTB as first entry argument and zero as second argument. The entry-context
builder copies these argument fields into the nonsecure CPU context.
Therefore generic BootShim already receives x0=DTB; the previous claimed
magic-as-DTB root cause is disproven. Default packer restored to the generic
shim. Fixed-DTB images are retained and explicitly labeled comparison-only.
The latest saved full expdb has a zero AEE header, no AEE0DEAD magic,
no TFA_DEBUG_BUF.gz section name and no gzip stream. It cannot supply a new
UEFI exception record. Missing LK strings cannot localize execution.
Next required evidence is same-attempt BootShim/SEC/DXE progress or a valid
AEE fault dump, with active-slot/readback identity. Device remains disconnected.


## Entry-only probe delivered
Built work/evidence-20261031/boot-rothko-entry-probe-7s-avbf.img.
SHA256 c302f7bb02b57e8fb77f4917a8015c18cde6a898075fc526587610ca017c0955.
64 MiB v4/AVBf, 128-byte entry shim, same 2 MiB FD retained as payload.
Probe writes only WDT LENGTH=0x3808 and RESTART=0x1971, preserves MODE,
then parks before any FD copy/SEC execution. The intended reset is about
7 seconds after shim entry. This is diagnostic, not a UEFI boot candidate.
Header, decompressed shim+FD equality and AVB digest passed offline.
A matching timing change is positive entry evidence; absence is inconclusive
because watchdog enable/access depends on hardware. No device operation done.
