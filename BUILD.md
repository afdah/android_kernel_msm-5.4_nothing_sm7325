# Reproducing the u/mr stealth stock-base `boot.img`

This branch (`sm7325/u/mr`) builds a Tier-3 stealth kernel for the Nothing Phone (1)
("spacewar", SM7325) that is byte-equivalent to stock Nothing OS 2.6
`Spacewar_U2.6-241031-1818` at the uname / `/proc/version` / vermagic / config level,
with debug/aging features OFF and LTO/CFI ON. The minimal flash changes ONLY `boot.img`.

## Prerequisites (external — not in this repo)

1. **Toolchain** — AOSP Clang/LLVM 11.0.2 `r383902b1` (build 6877366, `android11-qpr3-release`).
   Set `TOOLCHAIN` to its install root (must contain `bin/clang`, `bin/ld.lld`, `bin/llvm-*`).
   Source: https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/android11-qpr3-release/clang-r383902b1.tar.gz
2. **mkbootimg** — `mkbootimg.py` + `unpack_bootimg.py` (AOSP `system/tools/mkbootimg`).
   Set `MKBOOTIMG` and `UNPACK` to their paths.
   Source: https://android.googlesource.com/platform/system/tools/mkbootimg
3. **Stock firmware** — `spike0en/nothing_archive` release `Spacewar_U2.6-241031-1818`,
   asset `image-boot.7z` -> extract `boot.img` (provides the stock ramdisk). Set `STOCK_BOOT`.
   Source: https://github.com/spike0en/nothing_archive/releases/tag/Spacewar_U2.6-241031-1818

## Build the kernel Image

    ./build_mr.sh
    # -> out-stealth/arch/arm64/boot/Image ; UTS_RELEASE = 5.4.242-qgki-g3f7ff67280a0

`build_mr.sh` uses `arch/arm64/configs/nothing_mr_stealth_defconfig` (stealth config:
`LOCALVERSION="-qgki-g3f7ff67280a0"`, `LOCALVERSION_AUTO=n`, `LTO_CLANG`/`THINLTO`/
`CFI_CLANG`/`CFI_CLANG_SHADOW=y`, `DEBUG_FS` off) + the stock-matching build banner
(`KBUILD_BUILD_USER=nothing`, `HOST=NTSV-J90017LA`, `TIMESTAMP="Thu Oct 31 18:49:26 CST 2024"`).

Full build (Image + dtbs + modules, needed later for KernelSU's `vendor_boot`):

    FULL=1 ./build_mr.sh

`dtbs` requires the devicetree repo `afdah/android_kernel_devicetree_nothing_sm7325`
symlinked at `vendor/`; `modules` requires the audio-symlink fix already in this branch.

## Pack boot.img

    ./pack_mr.sh
    # -> boot.img  (our Image + stock ramdisk; ANDROID! v3; os 11.0.0 / patch 2022-11; cmdline '')

## Flash (minimal — boots stock-equivalent)

    fastboot flash --disable-verity --disable-verification boot boot.img
    fastboot reboot

Keep **stock** `vbmeta`, `vendor_boot`, `dtbo` (do NOT reflash them). Verify on device:

- `uname -r` == `5.4.242-qgki-g3f7ff67280a0`
- `cat /proc/version` byte-matches stock (`nothing@NTSV-J90017LA`, clang 11.0.2, Oct 31 2024)
- `zcat /proc/config.gz | grep -E 'LTO|CFI_CLANG|DEBUG_FS|LOCALVERSION_AUTO'` -> LTO/CFI on,
  `DEBUG_FS` off, `LOCALVERSION_AUTO` off (the tell that this is our kernel — stock has it on)

## Notes

- `boot.img` (v3) carries no dtb -> the base needs only `make Image` (no devicetree, no modules).
- Tier-3 stealth = uname / `/proc/version` / vermagic byte-exact to stock; the only behavioral
  tell is `LOCALVERSION_AUTO is not set`.
- Rollback: reflash stock `boot.img` (+ stock vbmeta/vendor_boot/dtbo if those were touched).

## KernelSU build (optional, on top of the base)

Adds KernelSU-Next (manual-hook mode, built-in) to the base Image. Same stealth
vermagic (`5.4.242-qgki-g3f7ff67280a0`); KSU is built-in so the minimal flash is
still ONLY `boot.img`.

### 4th external dependency (KSU kernel source)
- **KernelSU-Next (afdah fork) @ `sm7325/u/mr`** — https://github.com/afdah/KernelSU-Next
  (`build_ksu_mr.sh` clones+pins this automatically at the recorded commit; override
  `KSU_URL`/`KSU_PIN`). The fork's `sm7325/u/mr` branch carries two patches on top of
  the upstream `eb139a6d` pin: k5_fix (`selinux_hide.c`) + accept-v3 (`allowlist.c`).
  NOTE: the manager APK is separate — rifsxd/KernelSU-Next releases (the v3.2.0-spoofed
  manager sends profile v3; our kernel accepts v3+v4).

### Build

    ./build_ksu_mr.sh        # -> out-ksu/arch/arm64/boot/Image
    ./pack_mr.sh             # -> boot.img  (reuse the base pack_mr.sh; set OUT=out-ksu)

`build_ksu_mr.sh` clones the fork at the pin (patches already present), asserts the
committed tree state (seccomp.h comment-trick, 6 manual hooks, path_umount backports),
then applies the base defconfig + KSU config overlay + SCS force-keep + hard asserts.

### Config notes (boot-critical)
- `CONFIG_KSU=y`, `CONFIG_KSU_MANUAL_HOOK=y`, `CONFIG_KSU_KPROBES_HOOK=n` (manual hooks
  are committed in `fs/*` + `kernel/reboot.c`; kprobe mode panics on 5.4 — `sys_enter`
  tracepoint — so manual mode is used).
- `CONFIG_SHADOW_CALL_STACK` is FORCE-KEPT: enabling KSU makes `olddefconfig` drop SCS,
  which breaks boot (stock vendor modules are SCS-instrumented); `build_ksu_mr.sh`
  re-enables it after `olddefconfig` and asserts `SCS=y` (aborts otherwise).
- `include/linux/seccomp.h` is the committed comment-trick version (no `filter_count`
  field; the comment makes the KSU Kbuild `grep` skip re-adding it). Do NOT re-add
  `filter_count` — the struct-type shift breaks LTO codegen and hangs at the logo.

### Flash (same minimal model as the base)

    fastboot flash --disable-verity --disable-verification boot boot.img
    fastboot reboot

Keep stock `vbmeta` / `vendor_boot` / `dtbo`. Install the KernelSU-Next manager (v3.2.0
spoof) -> "Working" -> grant root to Shell. Verify:

    uname -r                                         # 5.4.242-qgki-g3f7ff67280a0
    zcat /proc/config.gz | grep -E 'CONFIG_KSU|CONFIG_SHADOW_CALL_STACK|CONFIG_LTO'
    adb shell su -c id                               # uid=0(root) context=u:r:ksu:s0

### Notes
- `KernelSU-Next/` is gitignored (it's the cloned fork) -> re-cloned each build.
- Repro is FUNCTIONAL only (ThinLTO `.llvm.<N>` non-determinism — not byte-identical).
