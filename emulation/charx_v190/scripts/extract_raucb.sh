#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_cmd unsquashfs
require_cmd sha256sum
require_cmd file

BUNDLE_SOURCE="${CHARX_BUNDLE_SOURCE:-${CHARX_WORKSPACE}/CHARXSEC3XXXSoftwareBundleV190.raucb}"
BUNDLE_TARGET="${CHARX_WORKSPACE}/CHARXSEC3XXXSoftwareBundleV190.raucb"
OUT_DIR="${CHARX_WORKSPACE}/work/firmware_v190_bundle"
TMP_DIR="${CHARX_WORKSPACE}/work/.extract_raucb_tmp"

[[ -f "$BUNDLE_SOURCE" ]] || die "Missing RAUCB bundle: $BUNDLE_SOURCE"

mkdir -p "${CHARX_WORKSPACE}/work"

if [[ "$BUNDLE_SOURCE" != "$BUNDLE_TARGET" ]]; then
  log "Copying RAUCB into workspace local artifact path"
  cp -p "$BUNDLE_SOURCE" "$BUNDLE_TARGET"
fi

bundle_type="$(file -b "$BUNDLE_TARGET")"
case "$bundle_type" in
  *Squashfs*) ;;
  *) die "Bundle is not recognized as SquashFS/RAUC: $bundle_type" ;;
esac

if [[ -f "$OUT_DIR/root.ext4" && -f "$OUT_DIR/bootimg.vfat" && -f "$OUT_DIR/manifest.raucm" && -f "$OUT_DIR/hook" ]]; then
  log "Bundle already extracted at $OUT_DIR"
else
  log "Extracting RAUCB bundle into $OUT_DIR"
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
  unsquashfs -f -d "$TMP_DIR" "$BUNDLE_TARGET" >/dev/null
  mkdir -p "$OUT_DIR"
  cp -p "$TMP_DIR"/root.ext4 "$TMP_DIR"/bootimg.vfat "$TMP_DIR"/manifest.raucm "$TMP_DIR"/hook "$OUT_DIR"/
  rm -rf "$TMP_DIR"
fi

chmod 0444 "$BUNDLE_TARGET" "$OUT_DIR"/root.ext4 "$OUT_DIR"/bootimg.vfat "$OUT_DIR"/manifest.raucm
chmod 0555 "$OUT_DIR"/hook || true

sha256sum "$BUNDLE_TARGET" "$OUT_DIR"/root.ext4 "$OUT_DIR"/bootimg.vfat "$OUT_DIR"/manifest.raucm "$OUT_DIR"/hook > "${CHARX_WORKSPACE}/work/firmware_v190_bundle.sha256"

log "Bundle extraction complete"
printf 'Bundle: %s\n' "$BUNDLE_TARGET"
printf 'Extracted: %s\n' "$OUT_DIR"
printf 'Hashes: %s\n' "${CHARX_WORKSPACE}/work/firmware_v190_bundle.sha256"
