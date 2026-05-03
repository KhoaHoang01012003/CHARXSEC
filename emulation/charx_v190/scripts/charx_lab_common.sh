#!/usr/bin/env bash
set -euo pipefail

CHARX_WORKSPACE="${CHARX_WORKSPACE:-/mnt/d/CHARXSEC}"
CHARX_LAB_USER="${CHARX_LAB_USER:-}"

if [[ -z "${CHARX_LAB_USER}" ]]; then
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    CHARX_LAB_USER="${SUDO_USER}"
  else
    CHARX_LAB_USER="$(find /home -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | head -n 1 || true)"
  fi
fi

if [[ -z "${CHARX_LAB_USER}" ]]; then
  CHARX_LAB_USER="${USER:-root}"
fi

CHARX_LAB_HOME="${CHARX_LAB_HOME:-/home/${CHARX_LAB_USER}/charx_labs/charx_v190}"
CHARX_NETNS="${CHARX_NETNS:-charx_v190}"
CHARX_HOST_VETH="${CHARX_HOST_VETH:-charxv0}"
CHARX_NS_VETH="${CHARX_NS_VETH:-charxv1}"
CHARX_HOST_IP="${CHARX_HOST_IP:-172.31.90.1/30}"
CHARX_NS_IP="${CHARX_NS_IP:-172.31.90.2/30}"

ARTIFACT_DIR="${CHARX_LAB_HOME}/artifacts"
SOURCE_DIR="${ARTIFACT_DIR}/source"
ROOTFS_RO="${CHARX_LAB_HOME}/rootfs_ro"
BOOT_DIR="${CHARX_LAB_HOME}/boot"
VOLUME_DIR="${CHARX_LAB_HOME}/volumes"
RUNS_DIR="${CHARX_LAB_HOME}/runs"
MOCKS_DIR="${CHARX_LAB_HOME}/mocks"
EVIDENCE_DIR="${CHARX_LAB_HOME}/evidence"
SCRIPTS_DIR="${CHARX_LAB_HOME}/scripts"
STATE_DIR="${CHARX_LAB_HOME}/state"

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_root() {
  if [[ "$(id -u)" != "0" ]]; then
    die "This script requires root. Run with: wsl.exe -d Debian -u root -- bash -lc '<script>'"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

safe_lab_path() {
  local path="$1"
  case "$path" in
    /home/*/charx_labs/charx_v190|/home/*/charx_labs/charx_v190/*) return 0 ;;
    *) die "Refusing to operate outside lab path: $path" ;;
  esac
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
}

write_observation() {
  local file="$1"
  local label="$2"
  local event="$3"
  local message="$4"
  mkdir -p "$(dirname "$file")"
  local escaped
  escaped="$(printf '%s' "$message" | json_escape)"
  printf '{"ts":"%s","label":"%s","event":"%s","message":"%s"}\n' "$(date -Is)" "$label" "$event" "$escaped" >> "$file"
}

run_dir_for() {
  local run_id="$1"
  printf '%s/%s' "$RUNS_DIR" "$run_id"
}

rootfs_for() {
  local run_id="$1"
  printf '%s/rootfs_rw' "$(run_dir_for "$run_id")"
}

evidence_for() {
  local run_id="$1"
  printf '%s/%s' "$EVIDENCE_DIR" "$run_id"
}

copy_tree_preserve() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -aHAX --numeric-ids "$src"/ "$dst"/
  else
    cp -a "$src"/. "$dst"/
  fi
}

mount_if_needed() {
  local source="$1"
  local target="$2"
  shift 2
  mkdir -p "$target"
  if ! mountpoint -q "$target"; then
    mount "$@" "$source" "$target"
  fi
}

umount_if_mounted() {
  local target="$1"
  if mountpoint -q "$target"; then
    umount "$target" || umount -l "$target"
  fi
}

