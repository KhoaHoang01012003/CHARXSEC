#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
run_id="${1:?Usage: mount_run.sh <run_id>}"
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"

[[ -d "$run_root" ]] || die "Missing run rootfs: $run_root"
safe_lab_path "$run_root"

mkdir -p "$run_root/proc" "$run_root/sys" "$run_root/dev" "$run_root/dev/pts" "$run_root/run" "$run_root/var/volatile" "$run_root/data" "$run_root/log" "$run_root/identity" "$run_root/var/log"

mount_if_needed proc "$run_root/proc" -t proc
mount_if_needed sysfs "$run_root/sys" -t sysfs
mount_if_needed /dev "$run_root/dev" --bind
mount_if_needed devpts "$run_root/dev/pts" -t devpts -o mode=0620,ptmxmode=0666,gid=5
mount_if_needed tmpfs "$run_root/run" -t tmpfs -o mode=0755,nodev,nosuid,strictatime
mount_if_needed tmpfs "$run_root/var/volatile" -t tmpfs
mount_if_needed "$VOLUME_DIR/log.img" "$run_root/log" -o loop
mount_if_needed "$VOLUME_DIR/data.img" "$run_root/data" -o loop
mount_if_needed "$VOLUME_DIR/identity.img" "$run_root/identity" -o loop
mount_if_needed "$run_root/log" "$run_root/var/log" --bind

write_observation "$run_evidence/observations.jsonl" "observed_runtime" "runtime_mounts_ready" "Mounted proc/sys/dev/run/var/volatile/data/log/identity for ${run_id}."
log "Mounted run ${run_id}"

