#!/usr/bin/env bash
# pack_mr.sh — repack boot.img = our Image + stock ramdisk (minimal base). See BUILD.md.
set -eu
STOCK_BOOT=${STOCK_BOOT:-stock-boot.img}
MKBOOTIMG=${MKBOOTIMG:-mkbootimg.py}
UNPACK=${UNPACK:-unpack_bootimg.py}
OUT=${OUT:-out-stealth}
OUTPUT=${OUTPUT:-boot.img}
IMAGE="$OUT/arch/arm64/boot/Image"
[ -f "$IMAGE" ] || { echo "missing $IMAGE (run build_mr.sh first)"; exit 1; }
[ -f "$STOCK_BOOT" ] || { echo "missing stock boot.img: $STOCK_BOOT"; exit 1; }
TMP=$(mktemp -d)
echo "unpacking $STOCK_BOOT -> $TMP"
"$UNPACK" --boot "$STOCK_BOOT" --out "$TMP" >/dev/null 2>&1 || "$UNPACK" "$STOCK_BOOT" --out "$TMP" >/dev/null 2>&1 || { echo "unpack_bootimg failed (check UNPACK path/syntax)"; exit 1; }
RAMDISK=$(find "$TMP" -type f -iname '*ramdisk*' | head -1)
[ -n "$RAMDISK" ] || { echo "ramdisk not found in $TMP"; ls -la "$TMP"; exit 1; }
echo "ramdisk: $RAMDISK"
"$MKBOOTIMG" --header_version 3 --os_version 11.0.0 --os_patch_level 2022-11 \
  --kernel "$IMAGE" --ramdisk "$RAMDISK" --cmdline '' --output "$OUTPUT"
echo "wrote $OUTPUT ($(stat -c%s "$OUTPUT") bytes)"
echo "flash: fastboot flash --disable-verity --disable-verification boot $OUTPUT && fastboot reboot"
echo "(keep stock vbmeta / vendor_boot / dtbo)"
