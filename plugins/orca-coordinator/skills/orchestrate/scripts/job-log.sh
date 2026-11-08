#!/usr/bin/env bash
# Prints the log of the first job in a run whose name matches a regex, without color codes or timestamps, so you can
# read a deploy preview before approving it. Approve in a separate command (approve.sh).
# Usage: job-log.sh OWNER/REPO RUN_ID JOB_NAME_REGEX     e.g. job-log.sh octo/app 42450695380 '^preview'
set -euo pipefail
repo=$1 run=$2 pattern=$3
job=$(gh run view "$run" -R "$repo" --json jobs -q ".jobs[]|select(.name|test(\"$pattern\"))|.databaseId" | head -1)
if [ -z "$job" ]; then
  echo "no job matching '$pattern' in run $run" >&2
  exit 1
fi
gh api "repos/$repo/actions/jobs/$job/logs" | sed 's/\x1b\[[0-9;]*m//g; s/^[0-9TZ:.-]* //'
