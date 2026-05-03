#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root

if ip link show "$CHARX_HOST_VETH" >/dev/null 2>&1; then
  ip link del "$CHARX_HOST_VETH" || true
fi

if ip netns list | awk '{print $1}' | grep -qx "$CHARX_NETNS"; then
  ip netns del "$CHARX_NETNS" || true
fi

printf 'stopped\n' > "$STATE_DIR/network_mode"
log "Namespace stopped: $CHARX_NETNS"

