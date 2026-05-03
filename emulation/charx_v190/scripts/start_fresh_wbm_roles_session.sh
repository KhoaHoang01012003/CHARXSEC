#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
require_cmd unshare
require_cmd ip
require_cmd chroot
require_cmd sha256sum
require_cmd python3

run_id="${1:-wbm-roles-$(date -u +%Y%m%dT%H%M%SZ)}"
shift || true

session_state="$STATE_DIR/wbm_session.env"
if [[ -f "$session_state" ]]; then
  "$SCRIPT_DIR/stop_wbm_session.sh" >/dev/null 2>&1 || true
fi

run_dir="$(run_dir_for "$run_id")"
run_root="$(rootfs_for "$run_id")"
run_evidence="$(evidence_for "$run_id")"
observations="$run_evidence/observations.jsonl"

if [[ ! -d "$run_dir" ]]; then
  "$SCRIPT_DIR/new_run.sh" "$run_id" >/dev/null
fi

"$SCRIPT_DIR/mount_run_fresh_volumes.sh" "$run_id" >/dev/null

mkdir -p "$run_evidence/logs" "$run_evidence/probes" "$run_evidence/mock_transcripts" "$run_evidence/integrity"

cat >> "$run_evidence/deviations.md" <<'EOF'

## Fresh WBM roles session deviations

- This session uses fresh per-run `/data`, `/log`, and `/identity` lab volumes so it does not inherit state from earlier sessions.
- `/identity` contains only `synthetic_lab_identity`; no production UID, certificate, private key, or password is fabricated.
- Set isolated UTS hostname to `ev3000` because local V190 manifest/system config identify `compatible=ev3000`, and mosquitto templates exist for `ev3000`/`ev2000` only.
- Created synthetic `/etc/machine-id` inside the run copy only so mosquitto init can generate config. This is not production identity.
- Created runtime directories `/run/nginx`, `/var/log/nginx`, and `/data/user-app/website` because full SysV boot/syslog/user-app initialization is not running in this service replay.
- WBM credentials are not seeded or reset by this workflow. Default login tests use the vendor-documented credentials already represented by hashes in `/etc/charx/website.db`.
EOF

if [[ ! -s "$run_root/etc/machine-id" ]]; then
  printf '4348415258563139304c41424d4f434b\n' > "$run_root/etc/machine-id"
fi
mkdir -p "$run_root/run/nginx" "$run_root/var/log/nginx" "$run_root/data/user-app/website"

{
  echo "## pre-start hashes"
  sha256sum "$run_root/etc/charx/website.db" "$run_root/etc/charx/routePermissions.json"
  if [[ -f "$run_root/data/charx-website/website.db" ]]; then
    sha256sum "$run_root/data/charx-website/website.db"
  else
    echo "missing  $run_root/data/charx-website/website.db"
  fi
} > "$run_evidence/integrity/wbm_roles_pre_start_hashes.txt"

python3 - "$run_root/etc/charx/website.db" "$run_evidence/integrity/website_db_pre_start.json" <<'PY'
import json
import sqlite3
import sys

db_path, out_path = sys.argv[1], sys.argv[2]
con = sqlite3.connect(db_path)
rows = []
for username, password, role, systemuser in con.execute("select username,password,role,systemuser from user order by username"):
    rows.append({
        "username": username,
        "role": role,
        "systemuser": systemuser,
        "password_hash_prefix": password[:32],
        "password_hash_len": len(password),
    })
with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"db_path": db_path, "rows": rows}, f, indent=2)
PY

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
MODE=shared_network_fresh_per_run_volumes
EOF

write_observation "$observations" "observed_runtime" "fresh_wbm_roles_session_start" "Starting fresh WBM roles session ${run_id}; no password seeding, fresh per-run volumes."

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
} > "$RUN_EVIDENCE/probes/fresh_wbm_roles_network.txt"

for svc in "${services[@]}"; do
  init="/etc/init.d/${svc}"
  set +e
  timeout 60s chroot "$RUN_ROOT" /bin/sh -lc "$init start" > "$RUN_EVIDENCE/logs/${svc}.fresh_wbm_roles.start.log" 2>&1
  status=$?
  set -e
  printf '{"service":"%s","event":"fresh_wbm_roles_start","status":%s}\n' "$svc" "$status" >> "$RUN_EVIDENCE/probes/fresh_wbm_roles_services.jsonl"
  if [[ "$status" == "0" ]]; then
    started+=("$svc")
  fi
  sleep 4
done

{
  echo "## ss snapshot"
  ss -lntup || true
} > "$RUN_EVIDENCE/probes/fresh_wbm_roles_ports.txt"

{
  echo "## process list"
  ps auxww || true
} > "$RUN_EVIDENCE/probes/fresh_wbm_roles_processes.txt"

{
  echo "## post-start hashes"
  sha256sum "$RUN_ROOT/etc/charx/website.db" "$RUN_ROOT/etc/charx/routePermissions.json"
  if [[ -f "$RUN_ROOT/data/charx-website/website.db" ]]; then
    sha256sum "$RUN_ROOT/data/charx-website/website.db"
  else
    echo "missing  $RUN_ROOT/data/charx-website/website.db"
  fi
} > "$RUN_EVIDENCE/integrity/wbm_roles_post_start_hashes.txt"

python3 - "$RUN_ROOT/data/charx-website/website.db" "$RUN_EVIDENCE/integrity/website_db_runtime_post_start.json" <<'PY' || true
import json
import sqlite3
import sys

db_path, out_path = sys.argv[1], sys.argv[2]
con = sqlite3.connect(db_path)
rows = []
for username, password, role, systemuser in con.execute("select username,password,role,systemuser from user order by username"):
    rows.append({
        "username": username,
        "role": role,
        "systemuser": systemuser,
        "password_hash_prefix": password[:32],
        "password_hash_len": len(password),
    })
with open(out_path, "w", encoding="utf-8") as f:
    json.dump({"db_path": db_path, "rows": rows}, f, indent=2)
PY

{
  echo "WBM fresh roles session is running."
  echo "Run ID: $RUN_ID"
  echo "Try from Windows browser: https://localhost/"
  echo "If localhost is not forwarded, try the WSL IP shown below."
  hostname -I || true
  echo "Press Ctrl-C in this terminal or run stop_wbm_session.sh to stop."
} | tee "$RUN_EVIDENCE/probes/fresh_wbm_roles_access.txt"

while true; do
  sleep 3600
done
CHILD

