#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
require_cmd unshare
require_cmd ip
require_cmd chroot

run_id="${1:?Usage: run_isolated_smoke.sh <run_id> [service ...] }"
shift || true

run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
observations="$run_evidence/observations.jsonl"
mkdir -p "$run_evidence/logs" "$run_evidence/mock_transcripts"

[[ -d "$run_root" ]] || die "Missing run rootfs: $run_root"

services=("$@")
if [[ "${#services[@]}" -eq 0 ]]; then
  services=(mosquitto charx-system-config-manager charx-website nginx charx-jupicore)
fi

service_csv="$(IFS=,; printf '%s' "${services[*]}")"
write_observation "$observations" "observed_runtime" "isolated_smoke_start" "Starting isolated unshare smoke session with services: ${service_csv}."
write_observation "$observations" "unknown" "environment_limitation" "Named ip netns is not assumed persistent in WSL; using single-session unshare --net smoke replay."
printf 'unshare_single_session\n' > "$STATE_DIR/network_mode"

export RUN_ROOT="$run_root"
export RUN_EVIDENCE="$run_evidence"
export SCRIPT_DIR
export SERVICE_CSV="$service_csv"

unshare --net -- bash -s <<'CHILD'
set -euo pipefail
IFS=',' read -r -a services <<< "$SERVICE_CSV"

ip link set lo up
ip route del default 2>/dev/null || true
{
  echo "## ip addr"
  ip addr || true
  echo
  echo "## ip route"
  ip route || true
} > "$RUN_EVIDENCE/isolated_network.txt"

python3 "$SCRIPT_DIR/start_mocks.py" --evidence-dir "$RUN_EVIDENCE" --host 127.0.0.1 > "$RUN_EVIDENCE/logs/mocks.stdout.log" 2> "$RUN_EVIDENCE/logs/mocks.stderr.log" &
mock_pid=$!
echo "$mock_pid" > "$RUN_EVIDENCE/mocks.pid"
sleep 1

started=()
for svc in "${services[@]}"; do
  init="/etc/init.d/${svc}"
  if [[ ! -e "$RUN_ROOT$init" ]]; then
    printf '{"service":"%s","event":"missing_init"}\n' "$svc" >> "$RUN_EVIDENCE/service_replay.jsonl"
    continue
  fi
  set +e
  timeout 35s chroot "$RUN_ROOT" /bin/sh -lc "$init start" > "$RUN_EVIDENCE/logs/${svc}.start.log" 2>&1
  status=$?
  set -e
  printf '{"service":"%s","event":"start","status":%s}\n' "$svc" "$status" >> "$RUN_EVIDENCE/service_replay.jsonl"
  if [[ "$status" == "0" ]]; then
    started+=("$svc")
  fi
  sleep 2
done

{
  echo "## ss -lntup"
  ss -lntup || true
  echo
  echo "## process list"
  ps auxww || true
} > "$RUN_EVIDENCE/isolated_runtime_snapshot.txt"

sleep 3

for (( idx=${#started[@]}-1 ; idx>=0 ; idx-- )); do
  svc="${started[$idx]}"
  init="/etc/init.d/${svc}"
  set +e
  timeout 20s chroot "$RUN_ROOT" /bin/sh -lc "$init stop" > "$RUN_EVIDENCE/logs/${svc}.stop.log" 2>&1
  status=$?
  set -e
  printf '{"service":"%s","event":"stop","status":%s}\n' "$svc" "$status" >> "$RUN_EVIDENCE/service_replay.jsonl"
done

kill "$mock_pid" >/dev/null 2>&1 || true
wait "$mock_pid" >/dev/null 2>&1 || true
CHILD

"$SCRIPT_DIR/collect_evidence.sh" "$run_id" >/dev/null || true
write_observation "$observations" "observed_runtime" "isolated_smoke_complete" "Completed isolated unshare smoke replay for ${run_id}."
printf '%s\n' "$run_evidence"
