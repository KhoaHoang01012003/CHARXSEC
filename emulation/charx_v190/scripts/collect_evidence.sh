#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

run_id="${1:?Usage: collect_evidence.sh <run_id>}"
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
mkdir -p "$run_evidence/logs" "$run_evidence/diffs"

if command -v ip >/dev/null 2>&1 && ip netns list | awk '{print $1}' | grep -qx "$CHARX_NETNS"; then
  ip netns exec "$CHARX_NETNS" ss -lntup > "$run_evidence/port_bindings.txt" 2>&1 || true
  ip netns exec "$CHARX_NETNS" ip addr > "$run_evidence/ip_addr.txt" 2>&1 || true
  ip netns exec "$CHARX_NETNS" ip route > "$run_evidence/ip_route.txt" 2>&1 || true
else
  ss -lntup > "$run_evidence/port_bindings_host_namespace.txt" 2>&1 || true
fi

ps auxww > "$run_evidence/processes_host.txt" 2>&1 || true
find "$run_root/log" -maxdepth 3 -type f -printf '%p %s bytes\n' > "$run_evidence/log_files.txt" 2>/dev/null || true
find "$run_root/data" -maxdepth 4 -type f -printf '%p %s bytes\n' > "$run_evidence/data_files.txt" 2>/dev/null || true

diff -ruN "$ROOTFS_RO/etc/charx" "$run_root/etc/charx" > "$run_evidence/diffs/etc_charx.diff" 2>/dev/null || true
diff -ruN "$ROOTFS_RO/etc/nginx" "$run_root/etc/nginx" > "$run_evidence/diffs/etc_nginx.diff" 2>/dev/null || true

write_observation "$run_evidence/observations.jsonl" "observed_runtime" "evidence_collected" "Collected process, port, file, and config diff evidence for ${run_id}."
printf '%s\n' "$run_evidence"

