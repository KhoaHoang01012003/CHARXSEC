#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QILING_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB_DIR="${CHARX_LAB_DIR:-/home/khoa/charx_labs/charx_v190}"

default_venv_dir() {
  if [[ -w "${LAB_DIR}" ]]; then
    printf '%s\n' "${LAB_DIR}/qiling_venv"
  else
    printf '%s\n' "${HOME}/.charx_qiling_v190/qiling_venv"
  fi
}

VENV_DIR="${CHARX_QILING_VENV:-$(default_venv_dir)}"
PYTHON="${VENV_DIR}/bin/python"

usage() {
  cat <<'EOF'
Usage:
  qiling_lab.sh bootstrap
  qiling_lab.sh matrix
  qiling_lab.sh static-map --service <name> [runner args]
  qiling_lab.sh run --service <name> [runner args]
  qiling_lab.sh fuzz --service <name> [runner args]
  qiling_lab.sh smoke

Common runner args:
  --run-id <id>
  --rootfs <path>
  --timeout <seconds>
  --coverage none|drcov|basic
  --debugger none|gdb|idapro
  --debug-port <port>
  --hooks files,sockets,syscalls,blocks,memory
EOF
}

require_venv() {
  if [[ ! -x "${PYTHON}" ]]; then
    echo "Qiling venv not found at ${VENV_DIR}" >&2
    echo "Run: ${BASH_SOURCE[0]} bootstrap" >&2
    exit 1
  fi
}

arg_value() {
  local key="$1"
  shift
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "${key}" && $# -gt 1 ]]; then
      printf '%s\n' "$2"
      return 0
    fi
    shift
  done
  return 1
}

has_arg() {
  local key="$1"
  shift
  while [[ $# -gt 0 ]]; do
    [[ "$1" == "${key}" ]] && return 0
    shift
  done
  return 1
}

run_python_supervised() {
  local mode="$1"
  shift
  local args=("$@")
  local run_id
  local runner_timeout
  local debugger
  local supervisor_limit
  local rc

  run_id="$(arg_value --run-id "${args[@]}" || true)"
  if [[ -z "${run_id}" ]]; then
    run_id="qiling-$(date -u +%Y%m%dT%H%M%SZ)"
    args+=(--run-id "${run_id}")
  fi

  runner_timeout="$(arg_value --timeout "${args[@]}" || true)"
  runner_timeout="${runner_timeout:-20}"
  debugger="$(arg_value --debugger "${args[@]}" || true)"
  debugger="${debugger:-none}"

  echo "Run ID: ${run_id}"

  if [[ "${debugger}" != "none" || "${runner_timeout}" == "0" ]]; then
    "${PYTHON}" "${SCRIPT_DIR}/qiling_runner.py" --mode "${mode}" "${args[@]}"
    return $?
  fi

  supervisor_limit=$((runner_timeout + ${CHARX_QILING_SUPERVISOR_GRACE:-20}))
  mkdir -p "${QILING_DIR}/evidence/${run_id}"

  set +e
  timeout --kill-after=5s "${supervisor_limit}s" "${PYTHON}" "${SCRIPT_DIR}/qiling_runner.py" --mode "${mode}" "${args[@]}"
  rc=$?
  set -e

  if [[ "${rc}" == "124" || "${rc}" == "137" ]]; then
    cat >"${QILING_DIR}/evidence/${run_id}/supervisor_timeout.json" <<EOF
{
  "run_id": "${run_id}",
  "mode": "${mode}",
  "runner_timeout_seconds": ${runner_timeout},
  "supervisor_limit_seconds": ${supervisor_limit},
  "label": "observed_qiling_target",
  "behavior_claim_allowed": false,
  "notes": "The external supervisor killed the Qiling process because ql.emu_stop did not return control cleanly. This is an emulator limitation, not firmware behavior truth."
}
EOF
    echo "Qiling supervisor timeout; evidence: ${QILING_DIR}/evidence/${run_id}/supervisor_timeout.json" >&2
  fi

  return "${rc}"
}

ACTION="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "${ACTION}" in
  bootstrap)
    "${SCRIPT_DIR}/bootstrap_qiling.sh"
    ;;
  matrix)
    "${SCRIPT_DIR}/qiling_runner.py" --mode matrix "$@"
    ;;
  static-map)
    "${SCRIPT_DIR}/qiling_runner.py" --mode static-map "$@"
    ;;
  run)
    require_venv
    run_python_supervised instrumented-run "$@"
    ;;
  fuzz)
    require_venv
    run_python_supervised fuzz-harness "$@"
    ;;
  smoke)
    require_venv
    "${PYTHON}" - <<'PY'
import qiling
print("qiling_import=ok")
print("qiling_version=" + str(getattr(qiling, "__version__", "unknown")))
PY
    "${SCRIPT_DIR}/qiling_runner.py" --mode static-map --service charx-website
    run_python_supervised instrumented-run --service charx-website --timeout 5 --coverage basic --hooks files,sockets,syscalls,blocks,memory || true
    ;;
  ""|-h|--help|help)
    usage
    ;;
  *)
    echo "Unknown action: ${ACTION}" >&2
    usage >&2
    exit 2
    ;;
esac
