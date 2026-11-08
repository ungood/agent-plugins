---
name: orchestrate
description: Act as the orchestrator of supervised Orca workers, so the maintainer can keep giving feedback while work runs in parallel. Use when the maintainer asks you to orchestrate, spin up agents or workers for tasks, or check in on workers, PRs, merge queues and deploys.
---

# Orchestrate Orca workers

You're the orchestrator. The maintainer gives feedback, and you turn each item into a brief, start an Orca worker for it, answer the workers' questions, review and merge their PRs, approve deploys, and clean up. Stay unblocked: the maintainer should always be able to send the next item.

For command syntax, run `orca skills get orchestration` and `orca skills get orca-cli`. They print the guides that match the installed Orca. This skill covers the job and the gotchas those guides don't. Outside an Orca terminal on Linux, bare `orca` is the screen reader: use `orca-ide`.

## Your job, and what isn't

- **Delegate everything substantive**, including research and reading code to form a proposal. Write a brief and start a worker. Your own tool use is dispatching, quick status checks, reviewing diffs and previews, and small one-line fixes.
- **The maintainer decides; you recommend.** Bring every design question to them before code that depends on it, through AskUserQuestion: one decision per question, with context, links, a recommendation first and the alternatives. Read their answer closely: they often change the question.
- **Record decisions where the project keeps them** (an issue comment, a decisions log, whatever the repo's `AGENTS.md` says), and file new issues for new asks. Never only in your own notes.
- **Keep it simple.** When a worker's proposal has extra machinery, ask whether the maintainer's own description already covers it.
- **Report plainly, with links.** Every PR and issue as `[owner/repo#N](https://github.com/owner/repo/pull/N)`. Say what you're waiting on the maintainer for, with the exact command. Don't hide failures.

## Starting a worker

Pass the whole brief inline in `--spec`: the worker block below first, then the task. No brief files and no shared rules file. Project rules live in each repo's `AGENTS.md` and the project's own conventions, which the worker reads itself.

```text
You are a worker. How to work with the orchestrator (another Claude session, over Orca):
- Before anything the brief leaves open, send it a question with your recommendation first
  (orca orchestration send, type question) and wait for the answer. Never leave open questions in a PR or issue.
- Send a status when something changes, and worker_done with PR links when your PRs are green.
  No heartbeats, no polling loops.
- Anything you need from it (a decision, "please push", "please open this PR") must go through
  orca orchestration send. Text only in your terminal never reaches it.
- If a push or gh pr create is refused, don't work around it: send the branch, title and body instead.
- The orchestrator merges; you do not.
- Read the repo's AGENTS.md before you start, and follow it.

Task: <the maintainer's words, quoted; what you already know; steps; what done is>
```

The same rules are in this plugin's `worker` skill, for a worker that has the plugin installed.

The task part holds:

- The maintainer's words, quoted. What you already know: files, issues, related PRs, and other workers in flight it might collide with.
- Steps. Research or proposal first ("send the orchestrator one question, recommendations first, wait for the answer"), then build. Say it may push and open PRs after your OK. A brief that says "read-only" gets later pushes refused.
- What "done" is, and to send `worker_done` then.

Start it in a fresh worktree:

```sh
orca orchestration worker-start --spec "$spec" \
  --task-title "<short title>" --repo name:<repo> --worktree new-top-level --name <fresh-name> \
  --base-branch origin/main --agent claude --json | jq -c '{ok, err: .error}'
```

- Use `--repo path:<dir>` for a repo Orca doesn't know by name.
- Right after, check the worker isn't bypassing permissions. This must print 0:
  `ps -eo pid,etimes,args | grep -E '^ *[0-9]+ +[0-9]+ claude ' | grep -c dangerously`
- Never reuse a worktree name you just removed: Orca's background delete kills the new checkout.
- A worktree gets only what the repo checks in. Local MCP servers or settings from the main checkout aren't there.

## The mailbox

Run [scripts/orca-wait.sh](scripts/orca-wait.sh) in the background (`run_in_background`, 3600). It skips heartbeats, and exits on the first question, status, escalation or worker_done, printing the delivery id and each message. Then:

- **Answer a question** with `orca orchestration reply --id <msg> --body "..."`, never `send`: a worker blocked on its question misses separate messages.
- **Ack the delivery** (`orca orchestration check --ack <delivery> --json`) once handled, or the next wait returns it again.
- **Restart the wait** every time. Run only one at a time, and never start it with `&`: its output is lost.

## Waking and poking workers

- `orca orchestration send` only queues. A worker sitting at its prompt never sees it, and after `worker_done` its dispatch is closed: replies go nowhere, and its `ask` fails. To give it work, type the message itself into its terminal:
  `orca terminal send --terminal <agentTerminalHandle> --text "Orchestrator: <the message>" --enter --wait-submit 30`
  The handle comes from `orca orchestration worker-list --json`. A "no turn start was observed" warning means it was busy, and the message is queued.
- To see why a worker is quiet, read its screen: `orca terminal read --terminal <h> --screen`. Workers sometimes ask for help only in their own terminal, or wait on a permission prompt, and stall unseen.
- A worker near its context limit ignores terminal messages. Start a fresh one in the same worktree (`--worktree name:<name>`), with handoff notes in the spec.
- Two messages sent close together arrive in order. If you correct yourself, the worker may act on the first one before reading the second.

## Doing what workers can't

A worker's permissions often refuse `git push`, `gh pr create` and `gh issue create`. When a worker sends a branch, title and body, do it:

- Push from its worktree (`git -C <worktree> push -u origin <branch>`), then `gh pr create -R <owner/repo> --head <branch> --base main --title "<title>" --body-file <file>`.
- Fill in any placeholders afterwards with `gh pr edit --body-file`.

If you can't do something either (closing a PR, cancelling someone else's run), give the maintainer the exact `! gh ...` command.

## Reviewing and merging

Review and merge the way the repo's `AGENTS.md` says: who reviews what, the merge method, and whether you may merge on your own. Without guidance there, read the diff (`gh pr diff N -R <owner/repo>`), merge once CI is green, and ask the maintainer about anything that defines new requirements or UI they asked to see.

GitHub gotchas:

- **Merge queues.** Wait for checks first (`gh pr checks N -R <owner/repo> --watch`), then queue with plain `gh pr merge N -R <owner/repo>`, with no `--squash`, `--delete-branch` or `--auto`. On a PR whose checks are still pending, that command does nothing, silently. Confirm it's in the queue:
  `gh api graphql -f query='{repository(owner:"<owner>",name:"<repo>"){mergeQueue{entries(first:10){nodes{state position pullRequest{number}}}}}}'`
- **Batched queues.** PRs queued while a run is going form the next batch, and only the newest one's run tests the whole batch. If it fails and leaves, the older ones are retried without it.
- **Ejected PRs.** When a PR leaves the queue, find out why:
  `gh api graphql -f query='{repository(owner:"<owner>",name:"<repo>"){pullRequest(number:N){timelineItems(last:3,itemTypes:[REMOVED_FROM_MERGE_QUEUE_EVENT]){nodes{... on RemovedFromMergeQueueEvent{reason createdAt}}}}}}'`
  Then read the failing run with `gh run view <id> -R <owner/repo> --log-failed`, strip the color codes, and grep for errors.
- **A queued branch can't be pushed.** Dequeue it first (the `dequeuePullRequest` GraphQL mutation with the PR's node id), push, wait for CI, then re-queue.
- **Stacked PRs.** Never `--delete-branch` a PR another PR is based on. After a squash merge, the next PR conflicts: have its author merge `origin/main` (never force-push), then merge it.
- **Two fixes, each failing on what the other fixes:** combine them into one PR.

## Deploy approvals

Only if the maintainer has given you permission to approve deploys.

1. Find runs waiting for approval: `gh api "repos/<owner/repo>/actions/runs?status=waiting" -q '.workflow_runs[]|"\(.id) \(.display_title)"'`.
2. Read the preview job's log: `gh run view <run> -R <owner/repo> --log --job <job id>` (job ids from `gh run view <run> -R <owner/repo> --json jobs`). Check every change against what the merged PRs should do.
3. Approve in a **separate** command. Reading and approving in one command is a blind apply, and the classifier blocks it:
   `gh api -X POST repos/<owner/repo>/actions/runs/<run>/pending_deployments -F "environment_ids[]=<id>" -f state=approved -f comment="Preview read: <what it showed>"`
   The environment id comes from `gh api repos/<owner/repo>/actions/runs/<run>/pending_deployments -q '.[].environment.id'`.
4. Watch it finish (`gh run watch <run> -R <owner/repo> --exit-status`), then verify it yourself. Don't ask the maintainer to test what you can check.

## Cleaning up

Once a worker's PR is merged (or pushed and only awaiting review), check its worktree is clean and nothing is unpushed, then `orca worktree rm --worktree name:<name>` (or `git -C <repo> worktree remove <path>` for worktrees Orca didn't make), and delete the local branch. Leftovers show up as "discovered worktrees" in Orca.

## Check-in

Offer a `/loop 30m` check-in when work is in flight, and offer to pause it when nothing is.

1. **Workers:** `orca orchestration worker-list --json`, and read the screen of each live one. Clean up the done ones. Poke the stalled ones: type the message in.
2. **Mail:** read any queued messages (`orca orchestration check --types "worker_done,escalation,question,status" --json`) and answer them.
3. **PRs:** `gh pr list -R <owner/repo>` for each repo in play. Merge or queue the green ones, find out why any were ejected, and handle waiting deploy approvals.
4. **Anything slow:** `gh run list -R <owner/repo> -L 10` for hung runs, and look for an unqueued green PR. Fix it or report it.
5. Report in a few lines: what moved, what's waiting on the maintainer (with commands), and what's next.

## Safety

- Never print secret values. If a worker leaks one, tell the maintainer and let them decide on rotating it.
- For a risky change (migrations, auth), have a fresh agent review it read-only before it ships.
