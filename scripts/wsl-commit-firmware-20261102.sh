#!/bin/bash
# 提交固件改动（子模块 + 主仓）并推送到上游
set -u
export PATH=/home/ubuntu/bin:$PATH
R=/home/ubuntu/rothko-upstream-20261102/uefi-full

echo "=========== 1) Mu_Basecore 子模块 ==========="
cd "$R/Mu_Basecore" || exit 1
git checkout -b k70u-port-20261102 2>&1 | tail -2
git add MdeModulePkg/Core/Dxe/Gcd/Gcd.c \
        MdeModulePkg/Universal/BdsDxe/BdsEntry.c \
        UefiCpuPkg/Library/CpuExceptionHandlerLib/AArch64/CpuExceptionHandlerLib.c
git commit -q -F - <<'MSG'
fix(k70u): DXE 停住等看门狗，并补齐 pstore 调试转储

- Gcd.c: 在 CoreInitializeMemoryServices 的断言之前转储 PHIT 的
  EfiFreeMemoryBottom/Top 与全部资源描述 HOB，便于从 pstore 定位
- CpuExceptionHandlerLib.c: 异常发生时打印 CurrentEL/SCTLR/TCR_EL1/
  TTBR0_EL1/T0SZ，用于比对异常时刻与 SEC 时刻的翻译制式
- BdsEntry.c: 平台注册不到启动项时，打印标记后 CpuDeadLoop 停住，
  等待看门狗超时复位。PSCI SYSTEM_RESET 在该机型上等价于冷启动，
  会清掉 DRAM 中的 pstore 日志，因此不能主动复位
MSG
git log --oneline -1

echo
echo "=========== 2) 主仓 uefi-full ==========="
cd "$R" || exit 1
git add Platforms/Xiaomi/rothkoPkg/Include/APRIORI.inc \
        Platforms/Xiaomi/rothkoPkg/Library/MemoryMapLib/MemoryMapLib.c \
        Platforms/Xiaomi/rothkoPkg/UniXNUConfig.dsc.inc \
        Platforms/Xiaomi/rothkoPkg/rothko.dsc \
        Silicon/Silicium/SiliciumPkg/Library/FrameBufferSerialPortLib/FrameBufferSerialPortLib.c \
        Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c \
        Mu_Basecore
git commit -q -F - <<'MSG'
feat(k70u): 修正内存表与调度顺序，使 UEFI 完整启动到 BDS

- MemoryMapLib.c: 资源描述符属性改用 SYS_MEM_TESTED。Gcd.c 的
  CoreInitializeMemoryServices 要求掩码后恰好等于 PRESENT|INITIALIZED|
  TESTED，能力位集合会让它在 Found 判定上失败
- MemoryMapLib.c: 内存表裁到 3 GiB。3–4 GiB 段上的访问会触发
  address size fault（EL1、40 位 VA、L0 描述符均正常）
- MemoryMapLib.c: 新增 Watchdog 寄存器区 0x1C00B000（Device 属性），
  供后续需要时主动触发看门狗复位
- FrameBufferSerialPortLib.c: FbRegion 零初始化并检查查找返回值；
  缓存刷新钳制到已映射的显示区。未初始化时会把栈垃圾当作显示基址，
  导致 dc civac 打到未翻译地址并触发递归异常
- APRIORI.inc: 移出 BdsDxe。APRIORI 驱动先于其他驱动调度，会跑在
  HiiDatabaseDxe 之前，使 UefiHiiServicesLib 构造函数断言
- rothko.dsc: PcdDriverHealthConfigureForm 置零，按 UEFI 提供的开关
  跳过驱动健康检查（FV 内没有 SetupBrowserDxe，无 FormBrowser2 协议）
- UniXNUConfig.dsc.inc: 注释两条未在任何 DEC 中声明的 PCD，EDK2 会以
  error F001 拒绝构建
- 更新 Mu_Basecore 子模块指针
MSG
git log --oneline -1
git status --short | head -5
