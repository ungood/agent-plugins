#!/usr/bin/env bash
# Exits, printing them, as soon as any run in the given repos waits for a deployment approval. Gives up after 2 hours.
# Usage: approval-wait.sh OWNER/REPO...   (or set ORCA_REPOS="owner/a owner/b")
set -uo pipefail
if (($# > 0)); then repos=("$@"); else read -ra repos <<<"${ORCA_REPOS:-}"; fi
if ((${#repos[@]} == 0)); then
  echo "usage: approval-wait.sh OWNER/REPO... (or set ORCA_REPOS)" >&2
  exit 2
fi
for _ in $(seq 1 240); do
  out=""
  for r in "${repos[@]}"; do
    for id in $(gh api "repos/$r/actions/runs?status=waiting" -q '.workflow_runs[].id' 2>/dev/null); do
      out+="$r $id $(gh run view "$id" -R "$r" --json displayTitle -q .displayTitle)"$'\n'
    done
  done
  if [ -n "$out" ]; then
    printf '%s' "$out"
    exit 0
  fi
  sleep 30
done
echo "none waiting"
