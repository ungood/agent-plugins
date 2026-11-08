#!/usr/bin/env bash
# Waits on the bound Orca run's mailbox. Acks heartbeat-only deliveries and keeps waiting; prints and
# exits (without acking) on the first delivery carrying a real message. check prints pretty,
# multi-line JSON after one-line keepalives, so the whole stream is slurped.
set -uo pipefail
deadline=$(( $(date +%s) + ${1:-3600} ))
while (( $(date +%s) < deadline )); do
  out=$(orca orchestration check --wait --types "worker_done,escalation,question,status" --timeout-ms 900000 --json 2>/dev/null | grep -v _keepalive | jq -cs 'last')
  d=$(jq -r '.result.deliveryId // empty' <<<"$out" 2>/dev/null)
  real=$(jq -c '[.result.messages[]? | select(.type != "heartbeat") | {id, type, from_handle, subject, body, payload}]' <<<"$out" 2>/dev/null)
  if [[ -n "$real" && "$real" != "[]" ]]; then
    jq -n --arg d "$d" --argjson m "$real" '{delivery: $d, messages: $m}'
    exit 0
  fi
  [[ -n "$d" ]] && orca orchestration check --ack "$d" --json >/dev/null
done
echo '{"timeout": true}'
