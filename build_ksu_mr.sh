#!/usr/bin/env bash
# build_ksu_mr.sh — Nothing Phone (1) u/mr stealth KernelSU-Next (manual-hook, built-in) Image.
# Builds the KSU kernel on top of the u/mr stealth base. KSU is built-in, so the minimal
# flash is still ONLY boot.img (same as the base; keep stock vbmeta/vendor_boot/dtbo).
# Prereqs + env vars: see BUILD.md. Default TOOLCHAIN is the WSL build path.
#
# Clones afdah/KernelSU-Next @ KSU_PIN (which already carries the k5_fix + accept-v3
# patches on its sm7325/u/mr branch) and ASSERTS the committed kernel-tree state
# (seccomp.h comment-trick, 6 manual hooks, path_umount backports) before configuring.
# It does NOT patch the tree — everything is committed (kernel tree here; KSU-dir
# patches in the fork).
set -eu
TOOLCHAIN=${TOOLCHAIN:-/root/toolchain/aosp-clang-r383902b1}
OUT=${OUT:-out-ksu}
JOBS=${JOBS:-$(nproc)}
KSU_URL=${KSU_URL:-https://github.com/afdah/KernelSU-Next.git}
KSU_PIN=30dfe298548928cd2344b7c3340db08afd4e8324
LOCALVER='-qgki-g3f7ff67280a0'
export PATH="$TOOLCHAIN/bin:$PATH"
export LLVM=1 DISABLE_WRAPPER=1 ARCH=arm64 CC=clang
export CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu-
export KCFLAGS="-Wno-error=strict-prototypes -Wno-error=gnu -Wno-error=address-of-packed-member -Wno-unknown-warning-option -Wno-error=unknown-warning-option"
export LOCALVERSION=
export KBUILD_BUILD_USER=nothing KBUILD_BUILD_HOST=NTSV-J90017LA KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP="Thu Oct 31 18:49:26 CST 2024"

# 1. clone the fork + pin (patches already present in the pin commit)
if [ ! -e KernelSU-Next/.git ]; then
  git clone "$KSU_URL" KernelSU-Next
fi
git -C KernelSU-Next reset --hard "$KSU_PIN" 2>/dev/null || {
  git -C KernelSU-Next fetch origin
  git -C KernelSU-Next reset --hard "$KSU_PIN"
}
echo "KernelSU-Next @ $(git -C KernelSU-Next rev-parse --short HEAD) (pin $KSU_PIN)"

# 2. assert the KSU-dir patches are present at the pin
SH_K=KernelSU-Next/kernel/feature/selinux_hide.c
AL=KernelSU-Next/kernel/policy/allowlist.c
grep -q '^#if 0' "$SH_K" || { echo "ABORT: k5_fix #if 0 missing in $SH_K"; exit 1; }
grep -q '#ifndef KSU_KPROBES_HOOK' "$SH_K" || { echo "ABORT: k5_fix guard missing in $SH_K"; exit 1; }
grep -q 'profile->version != 3' "$AL" || { echo "ABORT: accept-v3 missing in $AL"; exit 1; }

# 3. assert the committed kernel-tree state (the squash landed it; Kbuild auto-backports skip)
SH=include/linux/seccomp.h
grep -q "atomic_t filter_count;" "$SH" || { echo "ABORT: seccomp.h comment-trick missing"; exit 1; }
sed -n '/struct seccomp {/,/};/p' "$SH" | grep -q filter_count && { echo "ABORT: seccomp.h struct has filter_count (boot-hang)"; exit 1; } || true
grep -q "ksu_handle_sys_reboot" kernel/reboot.c || { echo "ABORT: reboot hook missing"; exit 1; }
for f in fs/exec.c fs/open.c fs/read_write.c fs/stat.c; do
  grep -q "#ifdef CONFIG_KSU" "$f" || { echo "ABORT: $f missing KSU guard"; exit 1; }
done
grep -q '^int path_umount' fs/namespace.c || { echo "ABORT: namespace.c path_umount missing"; exit 1; }
grep -q '^int path_umount' fs/internal.h || { echo "ABORT: internal.h path_umount missing"; exit 1; }
# SusFS kernel-side files (Phase C)
grep -q 'obj-$(CONFIG_KSU_SUSFS) += susfs.o' fs/Makefile || { echo "ABORT: fs/Makefile susfs.o missing"; exit 1; }
for f in fs/susfs.c fs/sus_su.c include/linux/susfs.h include/linux/susfs_def.h include/linux/sus_su.h; do
  [ -f "$f" ] || { echo "ABORT: $f missing"; exit 1; }
done

# 4. config: base defconfig + KSU overlay
make O="$OUT" ARCH=arm64 nothing_mr_stealth_defconfig
scripts/config --file "$OUT/.config" \
  --enable CONFIG_KSU \
  --enable CONFIG_KSU_MANUAL_HOOK \
  --disable CONFIG_KSU_KPROBES_HOOK \
  --enable CONFIG_KSU_SUSFS \
  --enable CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT \
  --enable CONFIG_KSU_SUSFS_SUS_PATH \
  --enable CONFIG_KSU_SUSFS_SUS_MOUNT \
  --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT \
  --enable CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT \
  --enable CONFIG_KSU_SUSFS_SUS_KSTAT \
  --enable CONFIG_KSU_SUSFS_TRY_UMOUNT \
  --enable CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT \
  --enable CONFIG_KSU_SUSFS_SPOOF_UNAME \
  --enable CONFIG_KSU_SUSFS_ENABLE_LOG \
  --enable CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
  --enable CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \
  --enable CONFIG_KSU_SUSFS_OPEN_REDIRECT \
  --enable CONFIG_KSU_SUSFS_SUS_MAP \
  --disable CONFIG_KSU_SUSFS_SUS_OVERLAYFS \
  --disable CONFIG_KSU_SUSFS_SUS_SU \
  --enable CONFIG_SHADOW_CALL_STACK \
  --enable CONFIG_SHADOW_CALL_STACK_VMAP \
  --disable CONFIG_HEADER_TEST --disable CONFIG_KERNEL_HEADER_TEST --disable CONFIG_UAPI_HEADER_TEST
scripts/config --file "$OUT/.config" --set-str CONFIG_LOCALVERSION "$LOCALVER" --disable CONFIG_LOCALVERSION_AUTO
make O="$OUT" ARCH=arm64 olddefconfig
# olddefconfig may drop SCS when KSU is enabled -> re-force + syncconfig (NOT a 2nd olddefconfig)
scripts/config --file "$OUT/.config" \
  --enable CONFIG_SHADOW_CALL_STACK --enable CONFIG_SHADOW_CALL_STACK_VMAP \
  --set-str CONFIG_LOCALVERSION "$LOCALVER" --disable CONFIG_LOCALVERSION_AUTO
make O="$OUT" ARCH=arm64 syncconfig

# 5. hard asserts
grep -q '^CONFIG_KSU=y' "$OUT/.config" || { echo "ABORT: KSU not y"; exit 1; }
grep -q '^CONFIG_KSU_MANUAL_HOOK=y' "$OUT/.config" || { echo "ABORT: MANUAL_HOOK not y"; exit 1; }
grep -q '^CONFIG_KSU_KPROBES_HOOK=y' "$OUT/.config" && { echo "ABORT: KPROBES_HOOK is y"; exit 1; } || true
grep -q '^CONFIG_SHADOW_CALL_STACK=y' "$OUT/.config" || { echo "ABORT: SCS not y (boot needs it)"; exit 1; }
grep -q '^CONFIG_LTO_CLANG=y' "$OUT/.config" || { echo "ABORT: LTO not y (stealth)"; exit 1; }
grep -q '^CONFIG_KSU_SUSFS=y' "$OUT/.config" || { echo "ABORT: KSU_SUSFS not y"; exit 1; }
grep -q '^CONFIG_KSU_SUSFS_SUS_MOUNT=y' "$OUT/.config" || { echo "ABORT: KSU_SUSFS_SUS_MOUNT not y"; exit 1; }
grep -q '^CONFIG_KSU_SUSFS_SUS_SU=y' "$OUT/.config" && { echo "ABORT: KSU_SUSFS_SUS_SU is y (must be n)"; exit 1; } || true

# 6. build Image (KSU built-in; boot.img has no dtb -> Image only)
mkdir -p "$OUT"; printf '0\n' > "$OUT/.version"
rm -f "$OUT/include/generated/compile.h"
make O="$OUT" ARCH=arm64 -j"$JOBS" Image
echo "Built: $OUT/arch/arm64/boot/Image"
grep UTS_RELEASE "$OUT/include/generated/utsrelease.h" 2>/dev/null || true
echo "KernelSU strings: $(strings "$OUT/arch/arm64/boot/Image" | grep -ci KernelSU)"
echo "banner: $(strings "$OUT/arch/arm64/boot/Image" | grep -m1 'SMP PREEMPT')"
