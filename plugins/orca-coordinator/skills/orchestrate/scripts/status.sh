#!/usr/bin/env bash
# One-screen status for a check-in: live workers and the tail of each one's screen, open PRs, merge queues, and runs
# that are not finished (including deploys waiting for approval).
# Usage: status.sh OWNER/REPO...   (or set ORCA_REPOS="owner/a owner/b")
set -uo pipefail
if (($# > 0)); then repos=("$@"); else read -ra repos <<<"${ORCA_REPOS:-}"; fi

echo "== workers"
for h in $(orca orchestration worker-list --json |
  jq -r '.. | objects | select(.dispatchId? and .agentTerminalHandle? and .workerState=="ready") | .agentTerminalHandle' |
  sort -u); do
  path=$(orca terminal show --terminal "$h" --json 2>/dev/null | jq -r '.result.terminal.worktreePath // "?"')
  echo "--- ${path##*/} ($h)"
  orca terminal read --terminal "$h" --screen 2>&1 | grep -v '^\s*$' |
    grep -vE '^[─ ]+$|Tip:|auto mode on|👤|^❯|recap|/config|/clear' | tail -3
done

if ((${#repos[@]} == 0)); then
  echo "(no repos: pass OWNER/REPO arguments or set ORCA_REPOS)"
  exit 0
fi

echo "== open PRs"
for r in "${repos[@]}"; do
  gh pr list -R "$r" --json number,title,isDraft -q ".[]|\"$r#\(.number) \(.title[0:60])\""
done

echo "== merge queues"
for r in "${repos[@]}"; do
  gh api graphql -f query="{repository(owner:\"${r%/*}\",name:\"${r#*/}\"){mergeQueue{entries(first:10){nodes{state position pullRequest{number}}}}}}" \
    -q ".data.repository.mergeQueue.entries.nodes[]?|\"$r \(.position) #\(.pullRequest.number) \(.state)\""
done

echo "== unfinished runs"
for r in "${repos[@]}"; do
  gh run list -R "$r" -L 10 --json databaseId,headBranch,status,event,createdAt \
    -q ".[]|select(.status!=\"completed\")|\"$r \(.databaseId) \(.headBranch[0:34]) \(.event) \(.status) \(.createdAt[11:16])\""
done
date -u +%H:%MZ
