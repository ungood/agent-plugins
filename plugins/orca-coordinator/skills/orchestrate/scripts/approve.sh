#!/usr/bin/env bash
# Approves a run's pending deployment. Read the preview first (job-log.sh), in a separate command.
# Usage: approve.sh OWNER/REPO RUN_ID "<what the preview showed>"
set -euo pipefail
repo=$1 run=$2 comment=$3
env=$(gh api "repos/$repo/actions/runs/$run/pending_deployments" -q '.[].environment.id')
if [ -z "$env" ]; then
  echo "run $run has no pending deployment" >&2
  exit 1
fi
args=()
for id in $env; do args+=(-F "environment_ids[]=$id"); done
gh api -X POST "repos/$repo/actions/runs/$run/pending_deployments" \
  "${args[@]}" -f state=approved -f comment="Preview read: $comment" -q '.[0].state'
