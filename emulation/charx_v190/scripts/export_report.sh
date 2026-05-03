#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

run_id="${1:-}"
workspace_out="${CHARX_WORKSPACE}/emulation/charx_v190/evidence"
mkdir -p "$workspace_out"
mkdir -p "$workspace_out/artifacts"

status_file="$workspace_out/wsl_lab_status.md"
{
  printf '# WSL Lab Status - CHARX SEC-3100 V190\n\n'
  printf -- '- Exported at: `%s`\n' "$(date -Is)"
  printf -- '- WSL lab home: `%s`\n' "$CHARX_LAB_HOME"
  printf -- '- Workspace mirror: `%s`\n' "$CHARX_WORKSPACE"
  printf -- '- Network mode: `%s`\n' "$(cat "$STATE_DIR/network_mode" 2>/dev/null || echo not_started)"
  printf -- '- QEMU system boot status: `%s`\n' "$(cat "$ARTIFACT_DIR/qemu_system_boot_status.txt" 2>/dev/null || echo not_checked)"
  printf '\n## Prepared Artifacts\n\n'
  printf -- '- SHA256SUMS: `%s`\n' "$ARTIFACT_DIR/SHA256SUMS"
  printf -- '- Integrity report: `%s`\n' "$ARTIFACT_DIR/integrity_report.md"
  printf -- '- Boot files hash: `%s`\n' "$ARTIFACT_DIR/boot_files.sha256"
  printf -- '- Bootargs search: `%s`\n' "$ARTIFACT_DIR/bootargs_search.md"
  printf '\n## Latest Run\n\n'
  if [[ -n "$run_id" ]]; then
    printf -- '- Run ID: `%s`\n' "$run_id"
    printf -- '- Run evidence: `%s`\n' "$(evidence_for "$run_id")"
    printf -- '- Validation report: `%s`\n' "$(evidence_for "$run_id")/validation_report.md"
  else
    printf -- '- No run id provided.\n'
  fi
  printf '\n## Fidelity Boundary\n\n'
  printf 'This lab uses synthetic `/data`, `/log`, and `/identity` volumes. It is service replay infrastructure, not full hardware-fidelity emulation.\n'
} > "$status_file"

if [[ -n "$run_id" && -d "$(evidence_for "$run_id")" ]]; then
  mkdir -p "$workspace_out/$run_id"
  cp -a "$(evidence_for "$run_id")"/. "$workspace_out/$run_id"/
fi

for artifact in SHA256SUMS integrity_report.md boot_files.sha256 bootargs_search.md qemu-system-arm-machines.txt qemu_system_boot_status.txt prepare_report.md; do
  if [[ -e "$ARTIFACT_DIR/$artifact" ]]; then
    cp -p "$ARTIFACT_DIR/$artifact" "$workspace_out/artifacts/$artifact"
  fi
done

printf '%s\n' "$status_file"
