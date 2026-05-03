#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QILING_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LAB_DIR="${CHARX_LAB_DIR:-/home/khoa/charx_labs/charx_v190}"
RUN_ID="${CHARX_QILING_RUN_ID:-qiling-bootstrap-$(date -u +%Y%m%dT%H%M%SZ)}"

default_venv_dir() {
  if [[ -w "${LAB_DIR}" ]]; then
    printf '%s\n' "${LAB_DIR}/qiling_venv"
  else
    printf '%s\n' "${HOME}/.charx_qiling_v190/qiling_venv"
  fi
}

default_evidence_dir() {
  if [[ -w "${LAB_DIR}/evidence" ]]; then
    printf '%s\n' "${LAB_DIR}/evidence/${RUN_ID}"
  else
    printf '%s\n' "${QILING_DIR}/evidence/${RUN_ID}"
  fi
}

VENV_DIR="${CHARX_QILING_VENV:-$(default_venv_dir)}"
EVIDENCE_DIR="${CHARX_QILING_EVIDENCE_DIR:-$(default_evidence_dir)}"

mkdir -p "${EVIDENCE_DIR}"

if [[ ! -d "${LAB_DIR}/rootfs_ro" ]]; then
  echo "Missing rootfs_ro at ${LAB_DIR}/rootfs_ro" >&2
  exit 1
fi

python3 -m venv "${VENV_DIR}"
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -m pip install --upgrade pip setuptools wheel | tee "${EVIDENCE_DIR}/pip-bootstrap.log"
python -m pip install -r "${QILING_DIR}/requirements.txt" | tee "${EVIDENCE_DIR}/pip-qiling.log"

python - <<'PY' "${EVIDENCE_DIR}" "${VENV_DIR}" "${QILING_DIR}"
import importlib
import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

evidence_dir = Path(sys.argv[1])
venv_dir = Path(sys.argv[2])
qiling_dir = Path(sys.argv[3])

def module_version(name: str) -> str:
    try:
        mod = importlib.import_module(name)
    except Exception as exc:
        return f"import_error:{type(exc).__name__}:{exc}"
    return str(getattr(mod, "__version__", "version_unknown"))

versions = {
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "python": sys.version,
    "platform": platform.platform(),
    "venv": str(venv_dir),
    "qiling_dir": str(qiling_dir),
    "qiling": module_version("qiling"),
    "unicorn": module_version("unicorn"),
    "capstone": module_version("capstone"),
}

(evidence_dir / "environment_versions.json").write_text(
    json.dumps(versions, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

freeze = subprocess.check_output([sys.executable, "-m", "pip", "freeze"], text=True)
(evidence_dir / "pinned-requirements.txt").write_text(freeze, encoding="utf-8")

print(json.dumps(versions, indent=2, sort_keys=True))
print(f"Pinned requirements: {evidence_dir / 'pinned-requirements.txt'}")
PY

echo "Qiling bootstrap evidence: ${EVIDENCE_DIR}"
