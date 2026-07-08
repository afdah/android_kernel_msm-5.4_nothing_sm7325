#!/usr/bin/env bash
# build_mr.sh — Nothing Phone (1) u/mr stealth stock-equivalent kernel Image.
# Prereqs + env vars: see BUILD.md. Default TOOLCHAIN is the WSL build path.
set -eu
TOOLCHAIN=${TOOLCHAIN:-/root/toolchain/aosp-clang-r383902b1}
OUT=${OUT:-out-stealth}
JOBS=${JOBS:-$(nproc)}
FULL=${FULL:-0}
export PATH="$TOOLCHAIN/bin:$PATH"
export LLVM=1 DISABLE_WRAPPER=1 ARCH=arm64 CC=clang
export CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu-
export KCFLAGS="-Wno-error=strict-prototypes -Wno-error=gnu -Wno-error=address-of-packed-member -Wno-unknown-warning-option -Wno-error=unknown-warning-option"
export LOCALVERSION=
export KBUILD_BUILD_USER=nothing KBUILD_BUILD_HOST=NTSV-J90017LA KBUILD_BUILD_VERSION=1
export KBUILD_BUILD_TIMESTAMP="Thu Oct 31 18:49:26 CST 2024"
TARGETS="Image"; [ "$FULL" = 1 ] && TARGETS="Image dtbs modules"
make O="$OUT" ARCH=arm64 nothing_mr_stealth_defconfig
make O="$OUT" ARCH=arm64 olddefconfig
mkdir -p "$OUT"; printf '0\n' > "$OUT/.version"
make O="$OUT" ARCH=arm64 -j"$JOBS" $TARGETS
echo "Built: $TARGETS -> $OUT/arch/arm64/boot/Image"
grep UTS_RELEASE "$OUT/include/generated/utsrelease.h" 2>/dev/null || true
