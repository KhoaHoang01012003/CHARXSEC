#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=charx_lab_common.sh
. "${SCRIPT_DIR}/charx_lab_common.sh"

require_root
run_id="${1:-}"
run_evidence=""
if [[ -n "$run_id" ]]; then
  run_evidence="$(evidence_for "$run_id")"
  mkdir -p "$run_evidence"
fi

if ip netns list | awk '{print $1}' | grep -qx "$CHARX_NETNS"; then
  log "Namespace already exists: $CHARX_NETNS"
  exit 0
fi

set +e
ip netns add "$CHARX_NETNS"
status=$?
set -e

if [[ "$status" != "0" ]]; then
  mkdir -p "$STATE_DIR"
  printf 'ip_netns_unavailable\n' > "$STATE_DIR/network_mode"
  [[ -n "$run_evidence" ]] && write_observation "$run_evidence/observations.jsonl" "unknown" "environment_limitation" "ip netns add failed; fallback is unshare --net for service replay."
  die "ip netns add failed; WSL kernel may restrict named namespaces. Fallback is recorded."
fi

ip link add "$CHARX_HOST_VETH" type veth peer name "$CHARX_NS_VETH"
ip link set "$CHARX_NS_VETH" netns "$CHARX_NETNS"
ip addr add "$CHARX_HOST_IP" dev "$CHARX_HOST_VETH"
ip link set "$CHARX_HOST_VETH" up
ip netns exec "$CHARX_NETNS" ip addr add "$CHARX_NS_IP" dev "$CHARX_NS_VETH"
ip netns exec "$CHARX_NETNS" ip link set lo up
ip netns exec "$CHARX_NETNS" ip link set "$CHARX_NS_VETH" up
ip netns exec "$CHARX_NETNS" ip route del default 2>/dev/null || true
printf 'ip_netns\n' > "$STATE_DIR/network_mode"

{
  printf '# Network Namespace\n\n'
  printf -- '- Namespace: `%s`\n' "$CHARX_NETNS"
  printf -- '- Host veth: `%s` `%s`\n' "$CHARX_HOST_VETH" "$CHARX_HOST_IP"
  printf -- '- Namespace veth: `%s` `%s`\n' "$CHARX_NS_VETH" "$CHARX_NS_IP"
  printf -- '- Default route inside namespace: disabled\n'
  printf '\n## Namespace routes\n\n```text\n'
  ip netns exec "$CHARX_NETNS" ip route || true
  printf '```\n'
} > "$STATE_DIR/network_namespace.md"

[[ -n "$run_evidence" ]] && write_observation "$run_evidence/observations.jsonl" "observed_runtime" "network_namespace_ready" "Created ${CHARX_NETNS} with no default route."
log "Namespace ready: $CHARX_NETNS"
