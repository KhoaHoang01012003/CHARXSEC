#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
require_cmd unshare
require_cmd ip
require_cmd chroot

run_id="${1:?Usage: run_wbm_probe.sh <run_id> [service ...] }"
shift || true
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
observations="$run_evidence/observations.jsonl"
mkdir -p "$run_evidence/logs" "$run_evidence/probes" "$run_evidence/mock_transcripts"

[[ -d "$run_root" ]] || die "Missing run rootfs: $run_root"

write_observation "$observations" "observed_runtime" "wbm_probe_start" "Starting WBM-focused probe with isolated net+uts namespace."

cat >> "$run_evidence/deviations.md" <<'EOF'

## WBM probe deviations

- Set isolated UTS hostname to `ev3000` because local V190 manifest/system config identify `compatible=ev3000`, and mosquitto templates exist for `ev3000`/`ev2000` only.
- Created synthetic `/etc/machine-id` inside the run copy only so mosquitto init can generate config. This is not production identity.
- Created runtime directories `/run/nginx`, `/var/log/nginx`, and `/data/user-app/website` because full SysV boot/syslog/user-app initialization is not running in this service replay.
EOF

if [[ ! -s "$run_root/etc/machine-id" ]]; then
  printf '4348415258563139304c41424d4f434b\n' > "$run_root/etc/machine-id"
fi
mkdir -p "$run_root/run/nginx" "$run_root/var/log/nginx" "$run_root/data/user-app/website"

services=("$@")
if [[ "${#services[@]}" -eq 0 ]]; then
  services=(mosquitto charx-system-config-manager charx-website nginx charx-jupicore)
fi
service_csv="$(IFS=,; printf '%s' "${services[*]}")"

export RUN_ROOT="$run_root"
export RUN_EVIDENCE="$run_evidence"
export SCRIPT_DIR
export SERVICE_CSV="$service_csv"

unshare --net --uts -- bash -s <<'CHILD'
set -euo pipefail
hostname ev3000
ip link set lo up
ip route del default 2>/dev/null || true

{
  echo "## hostname"
  hostname
  echo
  echo "## ip addr"
  ip addr || true
  echo
  echo "## ip route"
  ip route || true
} > "$RUN_EVIDENCE/probes/wbm_probe_network.txt"

IFS=',' read -r -a services <<< "$SERVICE_CSV"
started=()

for svc in "${services[@]}"; do
  init="/etc/init.d/${svc}"
  set +e
  timeout 60s chroot "$RUN_ROOT" /bin/sh -lc "$init start" > "$RUN_EVIDENCE/logs/${svc}.wbm_probe.start.log" 2>&1
  status=$?
  set -e
  printf '{"service":"%s","event":"wbm_probe_start","status":%s}\n' "$svc" "$status" >> "$RUN_EVIDENCE/probes/wbm_probe_services.jsonl"
  if [[ "$status" == "0" ]]; then
    started+=("$svc")
  fi
  sleep 4
done

for i in 1 2 3 4 5; do
  {
    echo "## ss snapshot $i"
    ss -lntup || true
  } >> "$RUN_EVIDENCE/probes/wbm_probe_ports.txt"
  sleep 5
done

probe_url() {
  local name="$1"
  local url="$2"
  shift 2
  set +e
  curl -k -sS -i --max-time 8 "$@" "$url" > "$RUN_EVIDENCE/probes/${name}.http" 2> "$RUN_EVIDENCE/probes/${name}.stderr"
  local status=$?
  set -e
  printf '{"probe":"%s","url":"%s","status":%s}\n' "$name" "$url" "$status" >> "$RUN_EVIDENCE/probes/wbm_http_probes.jsonl"
}

probe_url nginx_http_root http://127.0.0.1/
probe_url nginx_https_root https://127.0.0.1/
probe_url website_api_root http://127.0.0.1:5000/
probe_url website_guest_test http://127.0.0.1:5000/api/v1.0/web/test-auth-no-login
probe_url scm_root http://127.0.0.1:5001/
probe_url jupicore_root http://127.0.0.1:5555/

{
  echo "## process list"
  ps auxww || true
} > "$RUN_EVIDENCE/probes/wbm_probe_processes.txt"

for (( idx=${#started[@]}-1 ; idx>=0 ; idx-- )); do
  svc="${started[$idx]}"
  init="/etc/init.d/${svc}"
  set +e
  timeout 30s chroot "$RUN_ROOT" /bin/sh -lc "$init stop" > "$RUN_EVIDENCE/logs/${svc}.wbm_probe.stop.log" 2>&1
  status=$?
  set -e
  printf '{"service":"%s","event":"wbm_probe_stop","status":%s}\n' "$svc" "$status" >> "$RUN_EVIDENCE/probes/wbm_probe_services.jsonl"
done
CHILD

"$SCRIPT_DIR/collect_evidence.sh" "$run_id" >/dev/null || true
write_observation "$observations" "observed_runtime" "wbm_probe_complete" "Completed WBM-focused probe for ${run_id}."
printf '%s\n' "$run_evidence"
