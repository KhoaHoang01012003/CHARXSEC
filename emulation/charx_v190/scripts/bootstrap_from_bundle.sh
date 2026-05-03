#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root

log "Bootstrapping CHARX SEC-3100 V190 lab from RAUCB"
log "Workspace: ${CHARX_WORKSPACE}"
log "Lab home: ${CHARX_LAB_HOME}"
log "Lab user: ${CHARX_LAB_USER}"

bash "${SCRIPT_DIR}/extract_raucb.sh"

if [[ "${CHARX_SKIP_PREPARE:-0}" != "1" ]]; then
  bash "${SCRIPT_DIR}/prepare_lab.sh"
else
  log "Skipping prepare_lab.sh because CHARX_SKIP_PREPARE=1"
fi

if [[ "${CHARX_SKIP_QILING:-0}" != "1" ]]; then
  if [[ -x "${CHARX_WORKSPACE}/emulation/charx_v190/qiling/scripts/qiling_lab.sh" ]]; then
    log "Bootstrapping Qiling user environment as ${CHARX_LAB_USER}"
    runuser -u "$CHARX_LAB_USER" -- bash -lc "CHARX_LAB_DIR='${CHARX_LAB_HOME}' bash '${CHARX_WORKSPACE}/emulation/charx_v190/qiling/scripts/qiling_lab.sh' bootstrap"
  else
    log "Qiling lab script not found; skipping Qiling bootstrap"
  fi
else
  log "Skipping Qiling bootstrap because CHARX_SKIP_QILING=1"
fi

if [[ "${CHARX_START_FULL_SERVICE:-0}" == "1" ]]; then
  log "Starting full QEMU/chroot service stack"
  runuser -u "$CHARX_LAB_USER" -- bash -lc "CHARX_LAB_DIR='${CHARX_LAB_HOME}' bash '${CHARX_WORKSPACE}/emulation/charx_v190/scripts/charx_full_service.sh' start"
fi

cat <<EOF

Bootstrap complete.

Next commands from Windows PowerShell:

  .\\emulation\\charx_v190\\charx-full-service.cmd start
  .\\emulation\\charx_v190\\charx-full-service.cmd status
  .\\emulation\\charx_v190\\charx-qiling.cmd static-map --service all

Lab path:

  ${CHARX_LAB_HOME}

EOF
