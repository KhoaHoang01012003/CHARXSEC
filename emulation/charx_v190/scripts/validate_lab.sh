#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_cmd sha256sum
require_cmd python3

run_id="${1:-}"
report_dir="$EVIDENCE_DIR"
if [[ -n "$run_id" ]]; then
  report_dir="$(evidence_for "$run_id")"
fi
mkdir -p "$report_dir"
report="$report_dir/validation_report.md"
observations="$report_dir/observations.jsonl"

manifest_root_hash="$(awk -F= '/^\[image.rootfs\]/{in_root=1; next} /^\[/{in_root=0} in_root && $1=="sha256"{print $2}' "$SOURCE_DIR/manifest.raucm")"
manifest_boot_hash="$(awk -F= '/^\[image.kernel\]/{in_kernel=1; next} /^\[/{in_kernel=0} in_kernel && $1=="sha256"{print $2}' "$SOURCE_DIR/manifest.raucm")"
actual_root_hash="$(sha256sum "$SOURCE_DIR/root.ext4" | awk '{print $1}')"
actual_boot_hash="$(sha256sum "$SOURCE_DIR/bootimg.vfat" | awk '{print $1}')"

rc5_file="$report_dir/rc5_start_order.txt"
find "$ROOTFS_RO/etc/rc5.d" -maxdepth 1 ! -type d -printf '%f -> %l\n' | sort > "$rc5_file"

ports_file="$report_dir/configured_ports.txt"
grep -RHE '^(Host|Port|MqttPort|ServerPort|DiscoveryPort|ApiPort|LmgtPort)=' "$ROOTFS_RO/etc/charx" 2>/dev/null | sed "s#${ROOTFS_RO}/##" | sort > "$ports_file" || true

route_summary="$report_dir/route_permissions_summary.json"
python3 - "$ROOTFS_RO/etc/charx/routePermissions.json" > "$route_summary" <<'PY'
import json, sys
from collections import Counter
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
methods = Counter()
roles = Counter()
restricted = 0
for route, method_map in data.items():
    if not isinstance(method_map, dict):
        continue
    for method, rule in method_map.items():
        if not isinstance(rule, dict):
            continue
        methods[method] += 1
        role = rule.get("role", "unknown")
        roles[role] += 1
        if "restrictedUsers" in rule:
            restricted += 1
print(json.dumps({
    "route_patterns": len(data),
    "method_entries": sum(methods.values()),
    "methods": dict(sorted(methods.items())),
    "roles": dict(sorted(roles.items())),
    "restricted_user_rules": restricted,
}, indent=2, sort_keys=True))
PY

boot_inventory="$report_dir/boot_inventory.txt"
find "$BOOT_DIR" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort > "$boot_inventory"

network_safety="$report_dir/network_safety.txt"
{
  if command -v ip >/dev/null 2>&1 && ip netns list | awk '{print $1}' | grep -qx "$CHARX_NETNS"; then
    printf 'network_mode=ip_netns\n'
    ip netns exec "$CHARX_NETNS" ip route || true
  else
    printf 'network_mode=%s\n' "$(cat "$STATE_DIR/network_mode" 2>/dev/null || echo not_started)"
  fi
} > "$network_safety"

{
  printf '# CHARX SEC-3100 V190 Lab Validation Report\n\n'
  printf -- '- Generated at: `%s`\n' "$(date -Is)"
  printf -- '- Lab home: `%s`\n' "$CHARX_LAB_HOME"
  [[ -n "$run_id" ]] && printf -- '- Run ID: `%s`\n' "$run_id"
  printf '\n## Integrity\n\n'
  printf '| Artifact | Manifest SHA256 | Actual SHA256 | Result |\n'
  printf '|---|---|---|---|\n'
  printf '| root.ext4 | `%s` | `%s` | %s |\n' "$manifest_root_hash" "$actual_root_hash" "$([[ "$manifest_root_hash" == "$actual_root_hash" ]] && echo PASS || echo FAIL)"
  printf '| bootimg.vfat | `%s` | `%s` | %s |\n' "$manifest_boot_hash" "$actual_boot_hash" "$([[ "$manifest_boot_hash" == "$actual_boot_hash" ]] && echo PASS || echo FAIL)"
  printf '\n## Static Validation\n\n'
  printf -- '- rc5 start order: `%s`\n' "$rc5_file"
  printf -- '- configured ports: `%s`\n' "$ports_file"
  printf -- '- route permissions summary: `%s`\n' "$route_summary"
  printf -- '- boot inventory: `%s`\n' "$boot_inventory"
  printf '\n## Safety\n\n'
  printf -- '- network safety: `%s`\n' "$network_safety"
  printf -- '- synthetic volumes: `/data`, `/log`, `/identity`\n'
  printf -- '- QEMU system boot status: `%s`\n' "$(cat "$ARTIFACT_DIR/qemu_system_boot_status.txt" 2>/dev/null || echo not_checked)"
  printf '\n## Fidelity Boundary\n\n'
  printf 'This validation confirms lab integrity and static readiness only. It does not claim full hardware fidelity.\n'
} > "$report"

write_observation "$observations" "observed_from_artifact" "validation_complete" "Generated validation report at ${report}."
printf '%s\n' "$report"
