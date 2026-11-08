---
name: worker
description: How a dispatched Orca worker talks to its orchestrator. Use when you are an Orca worker (your prompt has a task ID and a dispatch ID, or says you are a worker) and need to ask a question, report status, hand over a push or PR, or finish.
---

# Work as an Orca worker

The orchestrator is another Claude session, talking to you over Orca. It can't see your terminal. For command syntax, use the official `orca:orchestration` skill, or run `orca skills get orchestration`.

- **Ask before you build.** Before anything the brief leaves open, send the orchestrator a question with your recommendation first, and wait for the answer. Use `orca orchestration ask` while your dispatch is open. It blocks until the answer comes. Never leave open questions in a PR or issue.
- **Everything goes through Orca.** Anything you need from the orchestrator (a decision, "please push", "please open this PR") must go through `orca orchestration send` or `ask`. Text only in your terminal never reaches it, and you sit stalled.
- **Send a status** when something changes, and `worker_done` with PR links when your PRs are green. Send `worker_done` exactly once. No heartbeats and no polling loops, unless your prompt asks for them.
- **Refused pushes.** If a push, `gh pr create` or `gh issue create` is refused, don't work around it: send the branch, title and body, and the orchestrator does it.
- **The orchestrator merges;** you don't. Once it has your PR, send `worker_done`. It will bring you back if CI or the merge queue fails.
- **After `worker_done` your dispatch is closed:** `ask` fails. If the orchestrator wakes you with new work, ask with `orca orchestration send --to <orchestrator handle> --type question`, and wait with `orca orchestration check --wait`.
- **Project rules** come from the repo's `AGENTS.md` and the project's own conventions. Read them before you start.
