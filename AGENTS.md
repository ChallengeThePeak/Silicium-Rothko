# Repository Instructions

- Keep K70U-specific changes under `Platforms/Xiaomi/rothkoPkg`,
  `Resources/Configs/rothko.toml`, and `Silicon/MediaTek/MT6989Pkg`.
- Preserve the unx18 UFS safety policy unless a matched hardware trace proves a
  specific replacement: keep the device refclk, skip destructive PHY/reset
  programming, and keep the published UFS disk path read-only.
- Do not commit `Build/`, `Conf/`, firmware images, device dumps, private keys,
  backup source files, or generated ramdisks.
- Record any shared `Silicon` or `Mu_Basecore` change separately from the board
  change and state why it also belongs upstream.
- Use the matching `UniXNU-rothko` package for payload and boot-image assembly.
  This repository owns the UEFI FD and board firmware behavior only.
