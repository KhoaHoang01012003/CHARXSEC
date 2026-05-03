#!/usr/bin/env bash
set -u

ACTION="${1:-status}"
shift || true

LAB_DIR="${CHARX_LAB_DIR:-${HOME}/charx_labs/charx_v190}"
WAIT_SECONDS="${CHARX_WAIT_SECONDS:-180}"
RUN_ID="${CHARX_RUN_ID:-}"
ROLE_PROBE="${CHARX_ROLE_PROBE:-1}"
OPEN_HINT=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      RUN_ID="${2:-}"
      shift 2
      ;;
    --wait)
      WAIT_SECONDS="${2:-120}"
      shift 2
      ;;
    --skip-role-probe)
      ROLE_PROBE=0
      shift
      ;;
    --no-open)
      OPEN_HINT=0
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

FULL_SERVICES=(
  mosquitto
  charx-system-config-manager
  charx-website
  nginx
  charx-jupicore
  charx-controller-agent
  charx-ocpp16-agent
  charx-modbus-server
  charx-modbus-agent
  charx-loadmanagement
)

PORT_PATTERN=':(80|81|443|1883|4444|4999|5000|5001|5002|5555|2106|1603|9502|9555|502)\b'

cd "$LAB_DIR" || {
  echo "Missing lab directory: $LAB_DIR" >&2
  exit 1
}

new_run_id() {
  date -u +"wbm-full-%Y%m%dT%H%M%SZ"
}

known_run_id() {
  if [[ -n "$RUN_ID" ]]; then
    printf '%s\n' "$RUN_ID"
  elif [[ -f /tmp/charx-full-last-run-id ]]; then
    cat /tmp/charx-full-last-run-id
  elif [[ -f state/wbm_session.env ]]; then
    # shellcheck disable=SC1091
    . state/wbm_session.env
    printf '%s\n' "${RUN_ID:-}"
  fi
}

show_ports() {
  ss -lntp 2>/dev/null | egrep "$PORT_PATTERN" || true
}

show_processes() {
  COLUMNS=200 LINES=40 ps -efww 2>/dev/null \
    | egrep 'CharxWebsite|CharxSystemConfigManager|CharxJupiCore|CharxOcpp16Agent|CharxModbus|CharxController|mosquitto|nginx|start_fresh_wbm_roles_session' \
    | grep -Ev 'egrep|grep -E' || true
}

http_smoke() {
  curl -k -sS -o /dev/null -w 'frontend https://localhost/ => %{http_code}\n' https://localhost/ 2>/dev/null || true
  curl -k -sS -o /dev/null -w 'system-name API => %{http_code}\n' https://localhost/api/v1.0/web/system-name 2>/dev/null || true
}

kill_fallback() {
  local pids
  pkill -f 'qemu-binfmt.*CharxControllerLoadmanagement' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*CharxModbusAgent' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*CharxModbusServer' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*CharxOcpp16Agent' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*CharxControllerAgent' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*CharxJupiCore' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*CharxWebsite' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*CharxSystemConfigManager' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*nginx' >/dev/null 2>&1 || true
  pkill -f 'qemu-binfmt.*mosquitto' >/dev/null 2>&1 || true
  pkill -f 'start_fresh_wbm_roles_session.sh' >/dev/null 2>&1 || true

  pids="$(COLUMNS=200 LINES=40 ps -efww 2>/dev/null \
    | awk '/start_fresh_wbm_roles_session[.]sh/ {print $2}')"
  if [[ -n "$pids" ]]; then
    # shellcheck disable=SC2086
    kill $pids >/dev/null 2>&1 || true
    sleep 1
    # shellcheck disable=SC2086
    kill -9 $pids >/dev/null 2>&1 || true
  fi

  pids="$(COLUMNS=200 LINES=40 ps -efww 2>/dev/null \
    | awk '/qemu-binfmt.*(Charx|mosquitto|nginx)/ {print $2}')"
  if [[ -n "$pids" ]]; then
    # shellcheck disable=SC2086
    kill $pids >/dev/null 2>&1 || true
    sleep 1
    # shellcheck disable=SC2086
    kill -9 $pids >/dev/null 2>&1 || true
  fi
}

stop_stack() {
  echo "Stopping CHARX full service stack..."

  if [[ -f state/wbm_session.env ]]; then
    ./scripts/stop_wbm_session.sh >/tmp/charx-full-stop.out 2>&1 || true
    cat /tmp/charx-full-stop.out
  else
    echo "[info] No active state/wbm_session.env found."
  fi

  echo "[info] Running cleanup fallback for orphaned lab processes..."
  kill_fallback
  sleep 2
  rm -f state/wbm_session.env

  echo
  echo "Remaining CHARX-related listeners:"
  show_ports
}

wait_for_stack() {
  local deadline=$((SECONDS + WAIT_SECONDS))
  local required=(443 5000 5555 2106 1603 9502 9555)

  while [[ $SECONDS -lt $deadline ]]; do
    local ports
    ports="$(show_ports)"
    local ok=1
    for port in "${required[@]}"; do
      if ! grep -q ":$port" <<<"$ports"; then
        ok=0
        break
      fi
    done
    [[ "$ok" == "1" ]] && return 0
    sleep 3
  done
  return 1
}

start_stack() {
  local run_id="$RUN_ID"
  if [[ -z "$run_id" ]]; then
    run_id="$(new_run_id)"
  fi

  echo "Starting CHARX SEC-3100 V190 full service stack..."
  echo "Run ID: $run_id"

  if [[ -f state/wbm_session.env ]] || show_processes | grep -q .; then
    echo "[info] Existing session/processes detected; stopping first."
    stop_stack >/tmp/charx-full-stop-before-start.out 2>&1 || true
    cat /tmp/charx-full-stop-before-start.out
  fi

  setsid -f ./scripts/start_fresh_wbm_roles_session.sh "$run_id" "${FULL_SERVICES[@]}" \
    >/tmp/charx-full-"$run_id".out 2>&1
  echo "$run_id" >/tmp/charx-full-last-run-id

  echo "[info] Waiting up to ${WAIT_SECONDS}s for full stack ports..."
  if ! wait_for_stack; then
    echo "[warn] Not all expected ports appeared before timeout."
  fi

  echo
  echo "Run ID: $run_id"
  echo "Start log: /tmp/charx-full-$run_id.out"
  echo "Evidence: $LAB_DIR/evidence/$run_id"
  echo
  echo "Listening ports:"
  show_ports
  echo
  echo "Processes:"
  show_processes
  echo
  echo "HTTP smoke:"
  http_smoke

  if [[ "$ROLE_PROBE" == "1" ]]; then
    echo
    echo "[info] Running WBM role activation probe through firmware APIs..."
    mkdir -p "$LAB_DIR/evidence/$run_id/probes"
    CHARX_WBM_BASE_URL=https://localhost ./scripts/probe_wbm_roles.py "$run_id" \
      >"$LAB_DIR/evidence/$run_id/probes/full_service_role_probe_stdout.json" \
      2>"$LAB_DIR/evidence/$run_id/probes/full_service_role_probe_stderr.log" || true

    echo "[info] Role probe summary:"
    if [[ -f "$LAB_DIR/evidence/$run_id/probes/wbm_role_probe_summary.json" ]]; then
      cat "$LAB_DIR/evidence/$run_id/probes/wbm_role_probe_summary.json"
    else
      echo "Role probe summary not found; inspect:"
      echo "$LAB_DIR/evidence/$run_id/probes/full_service_role_probe_stderr.log"
    fi
  fi

  echo
  echo "WBM URL: https://localhost/"
  if [[ "$ROLE_PROBE" == "1" ]]; then
    echo "Lab users after role activation workflow:"
    echo "  user / UserLab-20260424!"
    echo "  operator / OperatorLab-20260424!"
    echo "  manufacturer / ManufacturerLab-20260424!"
  else
    echo "Role probe skipped. Fresh run remains at vendor default auth state."
  fi

  if [[ "$OPEN_HINT" == "1" ]]; then
    echo "Open this URL from Windows browser: https://localhost/"
  fi
}

status_stack() {
  echo "Session state:"
  if [[ -f state/wbm_session.env ]]; then
    cat state/wbm_session.env
  else
    echo "No active session state."
  fi

  echo
  echo "Last full run id:"
  cat /tmp/charx-full-last-run-id 2>/dev/null || true

  echo
  echo "Processes:"
  show_processes

  echo
  echo "Listening ports:"
  show_ports

  echo
  echo "HTTP smoke:"
  http_smoke
}

logs_stack() {
  local run_id
  run_id="$(known_run_id)"
  if [[ -z "$run_id" ]]; then
    echo "No run id known. Pass --run-id <id> or start a run first."
    return 0
  fi

  echo "Run ID: $run_id"
  echo "Evidence: $LAB_DIR/evidence/$run_id"
  echo

  local files=(
    "evidence/$run_id/probes/fresh_wbm_roles_services.jsonl"
    "evidence/$run_id/probes/wbm_role_probe_summary.json"
    "evidence/$run_id/logs/charx-website.fresh_wbm_roles.start.log"
    "evidence/$run_id/logs/charx-jupicore.fresh_wbm_roles.start.log"
    "evidence/$run_id/logs/charx-ocpp16-agent.fresh_wbm_roles.start.log"
    "evidence/$run_id/logs/charx-modbus-agent.fresh_wbm_roles.start.log"
    "evidence/$run_id/logs/charx-modbus-server.fresh_wbm_roles.start.log"
    "evidence/$run_id/logs/charx-loadmanagement.fresh_wbm_roles.start.log"
    "evidence/$run_id/logs/charx-controller-agent.fresh_wbm_roles.start.log"
  )

  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      echo
      echo "### $f"
      tail -n 80 "$f"
    fi
  done
}

case "$ACTION" in
  start)
    start_stack
    ;;
  stop)
    stop_stack
    ;;
  restart)
    stop_stack
    echo
    start_stack
    ;;
  status)
    status_stack
    ;;
  logs)
    logs_stack
    ;;
  open)
    echo "Open from Windows browser: https://localhost/"
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|logs|open} [--run-id ID] [--wait SEC] [--skip-role-probe] [--no-open]" >&2
    exit 2
    ;;
esac
