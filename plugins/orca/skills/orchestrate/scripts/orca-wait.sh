#!/usr/bin/env bash
# Waits on the bound Orca run's mailbox. Acks heartbeat-only deliveries and keeps waiting; on the first delivery
# carrying a real message, prints the delivery id and each message's id, type, sender, subject and body, and exits
# without acking. check prints pretty, multi-line JSON after one-line keepalives, so the whole stream is slurped.
# Usage: orca-wait.sh [seconds]   (default 3600)
set -uo pipefail
deadline=$(($(date +%s) + ${1:-3600}))
while (($(date +%s) < deadline)); do
  out=$(orca orchestration check --wait --types "worker_done,escalation,question,status" --timeout-ms 900000 --json 2>/dev/null | grep -v _keepalive | jq -cs 'last')
  d=$(jq -r '.result.deliveryId // empty' <<<"$out" 2>/dev/null)
  real=$(jq -c '[.result.messages[]? | select(.type != "heartbeat")]' <<<"$out" 2>/dev/null)
  if [[ -n "$real" && "$real" != "[]" ]]; then
    echo "delivery: $d"
    jq -r '.[] | "\n\(.id) \(.type) from \(.from_handle)\n\(.subject // "")\n\(.body // "")"' <<<"$real"
    exit 0
  fi
  [[ -n "$d" ]] && orca orchestration check --ack "$d" --json >/dev/null
done
echo "timeout: no messages"
