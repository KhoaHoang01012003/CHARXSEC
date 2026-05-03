#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
require_cmd unshare
require_cmd ip
require_cmd chroot

run_id="${1:-wbm-session-$(date -u +%Y%m%dT%H%M%SZ)}"
shift || true

run_dir="$(run_dir_for "$run_id")"
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
observations="$run_evidence/observations.jsonl"
session_state="$STATE_DIR/wbm_session.env"

if [[ ! -d "$run_dir" ]]; then
  "$SCRIPT_DIR/new_run.sh" "$run_id" >/dev/null
fi

"$SCRIPT_DIR/mount_run.sh" "$run_id" >/dev/null

mkdir -p "$run_evidence/logs" "$run_evidence/probes" "$run_evidence/mock_transcripts"

cat >> "$run_evidence/deviations.md" <<'EOF'

## WBM interactive session deviations

- This session uses a shared network namespace so the WBM can be opened from the host browser. Unlike the isolated probe, this mode is intended for interactive UI access and is not an outbound-isolated fidelity claim.
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

cat > "$session_state" <<EOF
RUN_ID=${run_id}
PID=$$
STARTED_AT=$(date -Is)
SERVICES=${service_csv}
MODE=shared_network_uts_only
EOF

write_observation "$observations" "observed_runtime" "wbm_session_start" "Starting interactive WBM session ${run_id}; shared network, isolated UTS hostname ev3000."

export RUN_ID="$run_id"
export RUN_ROOT="$run_root"
export RUN_EVIDENCE="$run_evidence"
export SCRIPT_DIR
export SERVICE_CSV="$service_csv"

cleanup() {
  set +e
  "$SCRIPT_DIR/stop_wbm_session.sh" "$run_id" >/dev/null 2>&1 || true
}
trap cleanup INT TERM

unshare --uts -- bash -s <<'CHILD'
set -euo pipefail
hostname ev3000

IFS=',' read -r -a services <<< "$SERVICE_CSV"
started=()

{
  echo "## hostname"
  hostname
  echo
  echo "## ip addr"
  ip addr || true
  echo
  echo "## ip route"
  ip route || true
} > "$RUN_EVIDENCE/probes/wbm_session_network.txt"

for svc in "${services[@]}"; do
  init="/etc/init.d/${svc}"
  set +e
  timeout 60s chroot "$RUN_ROOT" /bin/sh -lc "$init start" > "$RUN_EVIDENCE/logs/${svc}.wbm_session.start.log" 2>&1
  status=$?
  set -e
  printf '{"service":"%s","event":"wbm_session_start","status":%s}\n' "$svc" "$status" >> "$RUN_EVIDENCE/probes/wbm_session_services.jsonl"
  if [[ "$status" == "0" ]]; then
    started+=("$svc")
  fi
  sleep 4
done

{
  echo "## ss snapshot"
  ss -lntup || true
} > "$RUN_EVIDENCE/probes/wbm_session_ports.txt"

probe_url() {
  local name="$1"
  local url="$2"
  shift 2
  set +e
  curl -k -sS -i --max-time 8 "$@" "$url" > "$RUN_EVIDENCE/probes/${name}.session.http" 2> "$RUN_EVIDENCE/probes/${name}.session.stderr"
  local status=$?
  set -e
  printf '{"probe":"%s","url":"%s","status":%s}\n' "$name" "$url" "$status" >> "$RUN_EVIDENCE/probes/wbm_session_http.jsonl"
}

probe_url nginx_http_root http://127.0.0.1/
probe_url nginx_https_root https://127.0.0.1/
probe_url website_api_root http://127.0.0.1:5000/
probe_url scm_root http://127.0.0.1:5001/
probe_url jupicore_root http://127.0.0.1:5555/

{
  echo "WBM session is running."
  echo "Run ID: $RUN_ID"
  echo "Try from Windows browser: https://localhost/"
  echo "If localhost is not forwarded, try the WSL IP shown below."
  hostname -I || true
  echo "Press Ctrl-C in this terminal or run stop_wbm_session.sh to stop."
} | tee "$RUN_EVIDENCE/probes/wbm_session_access.txt"

while true; do
  sleep 3600
done
CHILD

