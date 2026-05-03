#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
safe_lab_path "$CHARX_LAB_HOME"

run_id="${1:-$(date -u +%Y%m%dT%H%M%SZ)}"
run_dir="$(run_dir_for "$run_id")"
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"

[[ -e "$STATE_DIR/rootfs_ro.ready" ]] || die "Run prepare_lab.sh first"
[[ ! -e "$run_dir" ]] || die "Run already exists: $run_id"

mkdir -p "$run_dir" "$run_evidence/mock_transcripts" "$run_evidence/logs" "$run_evidence/diffs"
log "Creating run ${run_id}"
copy_tree_preserve "$ROOTFS_RO" "$run_root"

mkdir -p "$run_root/usr/bin" "$run_root/usr/libexec/qemu-binfmt"
cp -p "$(command -v qemu-arm-static)" "$run_root/usr/bin/qemu-arm-static"
cp -p "$(command -v qemu-arm-static)" "$run_root/usr/libexec/qemu-binfmt/arm-binfmt-P"

mkdir -p "$run_root/data" "$run_root/log" "$run_root/identity" "$run_root/run" "$run_root/var/volatile" "$run_root/dev/pts" "$run_root/proc" "$run_root/sys"

cat > "$run_dir/run.json" <<EOF
{
  "run_id": "${run_id}",
  "created_at": "$(date -Is)",
  "rootfs_rw": "${run_root}",
  "source_rootfs_ro": "${ROOTFS_RO}",
  "qemu_helper_injected": true,
  "identity_source": "synthetic_lab_identity",
  "behavior_claim": "lab_service_replay_not_full_hardware_fidelity"
}
EOF

{
  printf '# Deviations - %s\n\n' "$run_id"
  printf -- '- Injected `qemu-arm-static` into the run copy only. Original firmware artifact and `rootfs_ro` are not modified.\n'
  printf -- '- `/data`, `/log`, and `/identity` use synthetic lab ext4 images because no runtime dump exists.\n'
  printf -- '- `/identity` contains only a placeholder `synthetic_lab_identity`; no production UID, certificate, password, or private key is fabricated.\n'
  printf -- '- Any config change made during service replay must be recorded as `modified-runtime behavior`.\n'
} > "$run_evidence/deviations.md"

write_observation "$run_evidence/observations.jsonl" "observed_runtime" "run_created" "Created run ${run_id} with qemu helper in writable run copy."
chown -R "${CHARX_LAB_USER}:${CHARX_LAB_USER}" "$run_evidence" || true
printf '%s\n' "$run_id"
