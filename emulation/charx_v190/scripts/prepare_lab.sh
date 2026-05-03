#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
require_cmd sha256sum
require_cmd mount
require_cmd mkfs.ext4
require_cmd python3
require_cmd qemu-arm-static
require_cmd qemu-system-arm

safe_lab_path "$CHARX_LAB_HOME"

mkdir -p "$SOURCE_DIR" "$ROOTFS_RO" "$BOOT_DIR" "$VOLUME_DIR" "$RUNS_DIR" "$MOCKS_DIR" "$EVIDENCE_DIR" "$SCRIPTS_DIR" "$STATE_DIR"

log "Preparing CHARX lab at ${CHARX_LAB_HOME}"

if [[ ! -f "${CHARX_WORKSPACE}/work/firmware_v190_bundle/root.ext4" || ! -f "${CHARX_WORKSPACE}/work/firmware_v190_bundle/bootimg.vfat" || ! -f "${CHARX_WORKSPACE}/work/firmware_v190_bundle/manifest.raucm" ]]; then
  log "Extracted firmware bundle not found; extracting RAUCB first"
  bash "${SCRIPT_DIR}/extract_raucb.sh"
fi

for src in \
  "${CHARX_WORKSPACE}/CHARXSEC3XXXSoftwareBundleV190.raucb" \
  "${CHARX_WORKSPACE}/work/firmware_v190_bundle/root.ext4" \
  "${CHARX_WORKSPACE}/work/firmware_v190_bundle/bootimg.vfat" \
  "${CHARX_WORKSPACE}/work/firmware_v190_bundle/manifest.raucm" \
  "${CHARX_WORKSPACE}/work/firmware_v190_bundle/hook"; do
  [[ -e "$src" ]] || die "Missing source artifact: $src"
  cp -p "$src" "$SOURCE_DIR/"
done

chmod 0444 "$SOURCE_DIR"/CHARXSEC3XXXSoftwareBundleV190.raucb "$SOURCE_DIR"/root.ext4 "$SOURCE_DIR"/bootimg.vfat "$SOURCE_DIR"/manifest.raucm
chmod 0555 "$SOURCE_DIR"/hook || true

sha256sum \
  "$SOURCE_DIR/CHARXSEC3XXXSoftwareBundleV190.raucb" \
  "$SOURCE_DIR/root.ext4" \
  "$SOURCE_DIR/bootimg.vfat" \
  > "$ARTIFACT_DIR/SHA256SUMS"

manifest_root_hash="$(awk -F= '/^\[image.rootfs\]/{in_root=1; next} /^\[/{in_root=0} in_root && $1=="sha256"{print $2}' "$SOURCE_DIR/manifest.raucm")"
manifest_boot_hash="$(awk -F= '/^\[image.kernel\]/{in_kernel=1; next} /^\[/{in_kernel=0} in_kernel && $1=="sha256"{print $2}' "$SOURCE_DIR/manifest.raucm")"
actual_root_hash="$(sha256sum "$SOURCE_DIR/root.ext4" | awk '{print $1}')"
actual_boot_hash="$(sha256sum "$SOURCE_DIR/bootimg.vfat" | awk '{print $1}')"

{
  printf '# Integrity Validation\n\n'
  printf '| Artifact | Manifest SHA256 | Actual SHA256 | Result |\n'
  printf '|---|---|---|---|\n'
  printf '| root.ext4 | `%s` | `%s` | %s |\n' "$manifest_root_hash" "$actual_root_hash" "$([[ "$manifest_root_hash" == "$actual_root_hash" ]] && echo PASS || echo FAIL)"
  printf '| bootimg.vfat | `%s` | `%s` | %s |\n' "$manifest_boot_hash" "$actual_boot_hash" "$([[ "$manifest_boot_hash" == "$actual_boot_hash" ]] && echo PASS || echo FAIL)"
} > "$ARTIFACT_DIR/integrity_report.md"

[[ "$manifest_root_hash" == "$actual_root_hash" ]] || die "root.ext4 hash mismatch"
[[ "$manifest_boot_hash" == "$actual_boot_hash" ]] || die "bootimg.vfat hash mismatch"

if [[ ! -e "$STATE_DIR/rootfs_ro.ready" ]]; then
  log "Extracting root.ext4 read-only into rootfs_ro"
  tmp_mount="$(mktemp -d)"
  mount -o loop,ro "$SOURCE_DIR/root.ext4" "$tmp_mount"
  copy_tree_preserve "$tmp_mount" "$ROOTFS_RO"
  umount "$tmp_mount"
  rmdir "$tmp_mount"
  date -Is > "$STATE_DIR/rootfs_ro.ready"
else
  log "rootfs_ro already prepared; skipping extraction"
fi

if [[ ! -e "$STATE_DIR/boot.ready" ]]; then
  log "Extracting bootimg.vfat read-only into boot"
  tmp_mount="$(mktemp -d)"
  mount -o loop,ro "$SOURCE_DIR/bootimg.vfat" "$tmp_mount"
  cp -a "$tmp_mount"/. "$BOOT_DIR"/
  umount "$tmp_mount"
  rmdir "$tmp_mount"
  date -Is > "$STATE_DIR/boot.ready"
else
  log "boot already prepared; skipping extraction"
fi

find "$BOOT_DIR" -maxdepth 1 -type f -print0 | sort -z | xargs -0 sha256sum > "$ARTIFACT_DIR/boot_files.sha256"
qemu-system-arm -machine help > "$ARTIFACT_DIR/qemu-system-arm-machines.txt"

{
  printf '# Bootargs Search\n\n'
  printf 'This search records strings that may be bootargs or boot environment hints. It is not behavior truth by itself.\n\n'
  for f in "$BOOT_DIR"/oftree "$BOOT_DIR"/zImage-imx6ul-ksp0632.dtb "$ROOTFS_RO"/boot/barebox.bin "$ROOTFS_RO"/boot/barebox-*.bin; do
    [[ -e "$f" ]] || continue
    printf '## %s\n\n' "$f"
    strings "$f" | grep -Ei 'bootargs|console=|root=|mmcblk|system[01]|rauc|barebox' | head -200 || true
    printf '\n'
  done
} > "$ARTIFACT_DIR/bootargs_search.md"

if ! grep -qE 'bootargs|console=|root=' "$ARTIFACT_DIR/bootargs_search.md"; then
  printf 'unknown_bootargs\n' > "$ARTIFACT_DIR/qemu_system_boot_status.txt"
else
  printf 'bootargs_candidates_found_review_required\n' > "$ARTIFACT_DIR/qemu_system_boot_status.txt"
fi

create_volume() {
  local name="$1"
  local size="$2"
  local label="$3"
  local img="$VOLUME_DIR/${name}.img"
  if [[ -e "$img" ]]; then
    log "Volume exists: $img"
    return
  fi
  log "Creating ${name} lab volume (${size})"
  truncate -s "$size" "$img"
  mkfs.ext4 -F -L "$label" "$img" >/dev/null
  chmod 0644 "$img"
}

create_volume data 64M CHARX_DATA_LAB
create_volume log 64M CHARX_LOG_LAB
create_volume identity 16M CHARX_ID_LAB

if [[ ! -e "$STATE_DIR/identity.seeded" ]]; then
  tmp_mount="$(mktemp -d)"
  mount -o loop "$VOLUME_DIR/identity.img" "$tmp_mount"
  mkdir -p "$tmp_mount/lab-notes"
  cat > "$tmp_mount/lab-notes/synthetic_lab_identity.json" <<'JSON'
{
  "label": "synthetic_lab_identity",
  "source_type": "manual_test_stub",
  "evidence_tier": "Tier 4",
  "behavior_claim_allowed": false,
  "notes": "Placeholder only. This is not a production identity, certificate, UID, password, or provisioning dump."
}
JSON
  sync
  umount "$tmp_mount"
  rmdir "$tmp_mount"
  date -Is > "$STATE_DIR/identity.seeded"
fi

cp -p "${SCRIPT_DIR}"/*.sh "$SCRIPTS_DIR/"
cp -p "${SCRIPT_DIR}"/*.py "$SCRIPTS_DIR/" 2>/dev/null || true
chmod 0755 "$SCRIPTS_DIR"/*.sh "$SCRIPTS_DIR"/*.py 2>/dev/null || true

{
  printf '# CHARX SEC-3100 V190 Lab Prepare Report\n\n'
  printf -- '- Prepared at: `%s`\n' "$(date -Is)"
  printf -- '- Lab home: `%s`\n' "$CHARX_LAB_HOME"
  printf -- '- Workspace source: `%s`\n' "$CHARX_WORKSPACE"
  printf -- '- Rootfs source hash: `%s`\n' "$actual_root_hash"
  printf -- '- Boot image source hash: `%s`\n' "$actual_boot_hash"
  printf -- '- Rootfs read-only extract: `%s`\n' "$ROOTFS_RO"
  printf -- '- Boot extract: `%s`\n' "$BOOT_DIR"
  printf -- '- Volumes: `%s`\n' "$VOLUME_DIR"
  printf -- '- QEMU machine candidate: `mcimx6ul-evk`\n'
  printf -- '- QEMU system boot status: `%s`\n' "$(cat "$ARTIFACT_DIR/qemu_system_boot_status.txt")"
  printf '\nNotes:\n\n'
  printf -- '- Runtime lab volumes are synthetic and not production `/data`, `/log`, or `/identity`.\n'
  printf -- '- QEMU system boot remains experimental until bootargs are confirmed from evidence.\n'
} > "$ARTIFACT_DIR/prepare_report.md"

log "Prepare complete"
