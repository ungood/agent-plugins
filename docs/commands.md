# Defining Slash Commands

Slash commands are Markdown files that control Claude's behavior during interactive sessions.

## Command Structure

Commands are plain Markdown files with optional YAML frontmatter. The filename determines the command name (e.g., `my-command.md` becomes `/my-command`).

### Namespacing

Commands support directory-based namespacing. A file at `.claude/commands/frontend/component.md` creates `/component` with metadata showing "(project:frontend)".

### Arguments

Commands can reference arguments passed by the user:

- `$ARGUMENTS`: Captures all passed arguments
- `$1`, `$2`, etc.: Access specific positional parameters

### Bash Command Execution

Commands can execute bash operations using the `!` prefix in the command body. You must declare `allowed-tools: Bash(...)` in the frontmatter to enable this functionality.

Example:

```markdown
---
allowed-tools: Bash(git:*)
---

Run git status:

!git status
```

### File References

Commands can reference file contents using the `@` prefix, enabling commands to include and work with project files.

Example:

```markdown
Review the main configuration file at @config/app.json
```

## Frontmatter Options

Commands support optional YAML frontmatter:

| Option | Purpose |
| --------------------------- | ------------------------------------ |
| `description` | Brief command overview |
| `allowed-tools` | Permitted tool usage |
| `model` | Specific model selection |
| `argument-hint` | Expected arguments documentation |
| `disable-model-invocation` | Prevent AI execution |

## Skills vs. Slash Commands

Slash commands and Agent Skills serve different purposes:

- **Slash commands**: Quick, frequently-used prompts in single files
- **Skills**: Comprehensive capabilities requiring multiple files, scripts, and complex workflows

Both can coexist in projects.

## Reference

For complete documentation, see: <https://code.claude.com/docs/en/slash-commands>
