#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
run_id="${1:?Usage: run_service_replay.sh <run_id> [service ...] }"
shift || true

run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
observations="$run_evidence/observations.jsonl"
mkdir -p "$run_evidence/logs"

[[ -d "$run_root" ]] || die "Missing run rootfs: $run_root"

services=("$@")
if [[ "${#services[@]}" -eq 0 ]]; then
  services=(mosquitto charx-system-config-manager charx-website nginx charx-jupicore charx-ocpp16-agent charx-modbus-server charx-modbus-agent charx-loadmanagement)
fi

run_chroot() {
  local cmd="$1"
  if command -v ip >/dev/null 2>&1 && ip netns list | awk '{print $1}' | grep -qx "$CHARX_NETNS"; then
    ip netns exec "$CHARX_NETNS" chroot "$run_root" /bin/sh -lc "$cmd"
  else
    return 125
  fi
}

if ! command -v ip >/dev/null 2>&1 || ! ip netns list | awk '{print $1}' | grep -qx "$CHARX_NETNS"; then
  write_observation "$observations" "unknown" "service_replay_blocked" "Named network namespace is unavailable; refusing service replay to avoid host-network side effects."
  die "Named network namespace is required before service replay. Run start_namespace.sh <run_id> first."
fi

for svc in "${services[@]}"; do
  init="/etc/init.d/${svc}"
  if [[ ! -e "$run_root$init" ]]; then
    write_observation "$observations" "unknown" "service_missing" "${svc} init script not found."
    continue
  fi
  write_observation "$observations" "observed_runtime" "service_start_attempt" "Attempting ${svc} start."
  set +e
  timeout 30s bash -c "$(declare -f run_chroot); $(declare -p CHARX_NETNS run_root); run_chroot '$init start'" > "$run_evidence/logs/${svc}.start.log" 2>&1
  status=$?
  set -e
  if [[ "$status" == "0" ]]; then
    write_observation "$observations" "observed_runtime" "service_start_ok" "${svc} start returned 0."
  else
    write_observation "$observations" "unknown" "service_start_failed" "${svc} start returned ${status}; see logs/${svc}.start.log."
  fi
  sleep 2
done

"$SCRIPT_DIR/collect_evidence.sh" "$run_id" >/dev/null || true
printf '%s\n' "$run_evidence"
