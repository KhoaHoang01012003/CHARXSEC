#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
run_id="${1:?Usage: umount_run.sh <run_id>}"
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
safe_lab_path "$run_root"

for target in \
  "$run_root/var/log" \
  "$run_root/identity" \
  "$run_root/data" \
  "$run_root/log" \
  "$run_root/var/volatile" \
  "$run_root/run" \
  "$run_root/dev/pts" \
  "$run_root/dev" \
  "$run_root/sys" \
  "$run_root/proc"; do
  umount_if_mounted "$target"
done

write_observation "$run_evidence/observations.jsonl" "observed_runtime" "runtime_mounts_released" "Unmounted runtime filesystems for ${run_id}."
log "Unmounted run ${run_id}"

