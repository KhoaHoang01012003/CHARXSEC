#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root

run_id="${1:-}"
session_state="$STATE_DIR/wbm_session.env"

if [[ -z "$run_id" && -f "$session_state" ]]; then
  # shellcheck disable=SC1090
  . "$session_state"
  run_id="${RUN_ID:-}"
fi

[[ -n "$run_id" ]] || die "Usage: stop_wbm_session.sh <run_id> or create $session_state first"

run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
observations="$run_evidence/observations.jsonl"
safe_lab_path "$run_root"

services=(charx-jupicore nginx charx-website charx-system-config-manager mosquitto)
if [[ -f "$session_state" ]]; then
  # shellcheck disable=SC1090
  . "$session_state"
  if [[ -n "${SERVICES:-}" ]]; then
    IFS=',' read -r -a configured_services <<< "$SERVICES"
    services=()
    for (( idx=${#configured_services[@]}-1 ; idx>=0 ; idx-- )); do
      services+=("${configured_services[$idx]}")
    done
  fi
fi

mkdir -p "$run_evidence/logs" "$run_evidence/probes"

for svc in "${services[@]}"; do
  init="/etc/init.d/${svc}"
  if [[ -x "$run_root$init" ]]; then
    set +e
    timeout 30s chroot "$run_root" /bin/sh -lc "$init stop" > "$run_evidence/logs/${svc}.wbm_session.stop.log" 2>&1
    status=$?
    set -e
    printf '{"service":"%s","event":"wbm_session_stop","status":%s}\n' "$svc" "$status" >> "$run_evidence/probes/wbm_session_services.jsonl"
  fi
done

if [[ -n "${PID:-}" ]]; then
  kill "$PID" >/dev/null 2>&1 || true
fi

"$SCRIPT_DIR/collect_evidence.sh" "$run_id" >/dev/null || true
"$SCRIPT_DIR/umount_run.sh" "$run_id" >/dev/null || true

rm -f "$session_state"
write_observation "$observations" "observed_runtime" "wbm_session_stop" "Stopped interactive WBM session ${run_id}."
printf '%s\n' "$run_evidence"

