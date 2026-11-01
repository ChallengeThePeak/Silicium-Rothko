# Silicium-Rothko

Experimental UEFI bring-up for the Xiaomi Redmi K70 Ultra (`rothko`),
with Android boot v4 packaging and stock AVB-tail preservation.

The current firmware reaches DXE Core and stops at the memory initialization
assertion in `Gcd.c`. It is not a working operating-system port.

## Source Layout

All locally committed source versions are stored in this private repository:

- `main`: port notes, device-tree reference and boot-image tools.
- `uefi/rothko`: the `uefi-mtk-reference` submodule and platform sources.
- `basecore/rothko`: the customized `Mu_Basecore` submodule.

Other upstream dependencies retain their original submodule locations.

```sh
git clone --recurse-submodules https://github.com/ChallengeThePeak/Silicium-Rothko.git
```

## Build And Package

See [the pstore boot build guide](BUILD_PSTORE_BOOT.md) (Chinese) for the
WSL build, required UniXNU patch, v4/AVB packaging, log retrieval, and
same-device firmware / `vendor_boot` compatibility limits.

## Saved Versions

The `rothko-avb-v1` and `rothko-trace-v2` tags preserve the local rollback
points. Check out the current recursive clone before switching to these older
tags; the original tags retain their historical submodule URLs.

See [the port notes](ADAPTATION_PLAN.md) and
[the boot-container audit](BOOT_CONTAINER_AUDIT.md) for bring-up details.
Device images, partition dumps, runtime logs, build outputs and toolchains
remain outside this repository.
