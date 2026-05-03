#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
require_cmd dd
require_cmd mkfs.ext4

run_id="${1:?Usage: mount_run_fresh_volumes.sh <run_id>}"
run_dir="$(run_dir_for "$run_id")"
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
run_volumes="$run_dir/volumes"

[[ -d "$run_root" ]] || die "Missing run rootfs: $run_root"
safe_lab_path "$run_root"

mkdir -p "$run_volumes" "$run_evidence"

create_img() {
  local name="$1"
  local size_mb="$2"
  local image="$run_volumes/${name}.img"
  if [[ ! -f "$image" ]]; then
    dd if=/dev/zero of="$image" bs=1M count="$size_mb" status=none
    mkfs.ext4 -q -F "$image"
  fi
}

create_img data 64
create_img log 64
create_img identity 16

mkdir -p "$run_root/proc" "$run_root/sys" "$run_root/dev" "$run_root/dev/pts" "$run_root/run" "$run_root/var/volatile" "$run_root/data" "$run_root/log" "$run_root/identity" "$run_root/var/log"

mount_if_needed proc "$run_root/proc" -t proc
mount_if_needed sysfs "$run_root/sys" -t sysfs
mount_if_needed /dev "$run_root/dev" --bind
mount_if_needed devpts "$run_root/dev/pts" -t devpts -o mode=0620,ptmxmode=0666,gid=5
mount_if_needed tmpfs "$run_root/run" -t tmpfs -o mode=0755,nodev,nosuid,strictatime
mount_if_needed tmpfs "$run_root/var/volatile" -t tmpfs
mount_if_needed "$run_volumes/log.img" "$run_root/log" -o loop
mount_if_needed "$run_volumes/data.img" "$run_root/data" -o loop
mount_if_needed "$run_volumes/identity.img" "$run_root/identity" -o loop
mount_if_needed "$run_root/log" "$run_root/var/log" --bind

if [[ ! -f "$run_root/identity/synthetic_lab_identity.json" ]]; then
  cat > "$run_root/identity/synthetic_lab_identity.json" <<EOF
{
  "source": "synthetic_lab_identity",
  "run_id": "${run_id}",
  "created_at": "$(date -Is)",
  "behavior_claim_allowed": false
}
EOF
fi

cat > "$run_dir/volumes.json" <<EOF
{
  "run_id": "${run_id}",
  "volume_mode": "fresh_per_run",
  "data": "${run_volumes}/data.img",
  "log": "${run_volumes}/log.img",
  "identity": "${run_volumes}/identity.img",
  "identity_source": "synthetic_lab_identity",
  "behavior_claim": "runtime_state_is_lab_fresh_not_production_dump"
}
EOF

write_observation "$run_evidence/observations.jsonl" "observed_runtime" "fresh_runtime_mounts_ready" "Mounted fresh per-run /data, /log, and /identity volumes for ${run_id}."
log "Mounted fresh per-run volumes for ${run_id}"

