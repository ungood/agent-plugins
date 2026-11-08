---
name: hooks-creator
description: Create Claude Code hooks for automated validation, permission control, and workflow automation. Use when building event-driven scripts, enforcing code quality, or automating Claude Code interactions.
---

# Hooks Creator

Create hooks to automate validation, control permissions, and customize Claude Code workflows. Hooks are scripts or LLM prompts that trigger at specific events.

## Quick Start

Create `.claude/hooks/validate.sh`:

```bash
#!/usr/bin/env bash
set -e
input=$(cat)
command=$(echo "$input" | jq -r '.parameters.command // empty')
echo "$command" | grep -qE 'rm -rf|mkfs' && echo '{"decision": "deny"}' >&2 && exit 2
echo '{"decision": "allow"}'
```

Configure in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{"type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/validate.sh"}]
    }]
  }
}
```

## Core Patterns

Use **PreToolUse** to validate/block operations, **PostToolUse** for formatting/cleanup, **PermissionRequest** to auto-approve/deny, **UserPromptSubmit** to validate prompts, **SessionStart** to inject context.

Return JSON decisions: `{"decision": "allow"}`, `{"decision": "deny", "message": "..."}`, `{"decision": "ask"}`, or `{"decision": "block"}`. Exit 0 for success, 2 for blocking errors.

Use environment variables: `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_SESSION_ID`.

## References

- [references/hooks-reference.md](references/hooks-reference.md) - Complete technical reference with all 10 hook events, specs, and troubleshooting
- [references/examples.md](references/examples.md) - 15+ real-world hook implementations
- <https://code.claude.com/docs/en/hooks> - Official documentation
