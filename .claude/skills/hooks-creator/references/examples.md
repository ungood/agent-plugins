# Hook Examples

Real-world hook implementations for common use cases.

## Code Quality Enforcement

### Auto-format Code After Edits

Automatically run Prettier/Black/rustfmt after file edits.

**Configuration (.claude/settings.json):**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/format-code.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/format-code.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
tool=$(echo "$input" | jq -r '.tool')
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

# Only process Write/Edit operations with file paths
[[ -z "$file" ]] && exit 0
[[ "$tool" =~ ^(Write|Edit)$ ]] || exit 0

# Format based on file extension
if [[ "$file" =~ \.(ts|tsx|js|jsx|json|css|html)$ ]]; then
  echo "Formatting $file with Prettier..." >&2
  npx prettier --write "$file" 2>/dev/null || true
elif [[ "$file" =~ \.py$ ]]; then
  echo "Formatting $file with Black..." >&2
  black "$file" 2>/dev/null || true
elif [[ "$file" =~ \.rs$ ]]; then
  echo "Formatting $file with rustfmt..." >&2
  rustfmt "$file" 2>/dev/null || true
elif [[ "$file" =~ \.go$ ]]; then
  echo "Formatting $file with gofmt..." >&2
  gofmt -w "$file" 2>/dev/null || true
fi

exit 0
```

### Run Linter Before File Writes

Validate code quality before allowing writes.

**Configuration:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/lint-code.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/lint-code.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
tool=$(echo "$input" | jq -r '.tool')
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

# Only process Write/Edit operations
[[ "$tool" =~ ^(Write|Edit)$ ]] || {
  echo '{"decision": "allow"}'
  exit 0
}

# Skip if no file path
[[ -z "$file" ]] && {
  echo '{"decision": "allow"}'
  exit 0
}

# Lint TypeScript files
if [[ "$file" =~ \.(ts|tsx)$ ]]; then
  if ! npx eslint "$file" 2>/dev/null; then
    echo '{"decision": "ask", "message": "ESLint errors found. Proceed anyway?"}' >&2
    exit 2
  fi
fi

# Lint Python files
if [[ "$file" =~ \.py$ ]]; then
  if ! pylint "$file" 2>/dev/null; then
    echo '{"decision": "ask", "message": "Pylint errors found. Proceed anyway?"}' >&2
    exit 2
  fi
fi

echo '{"decision": "allow"}'
exit 0
```

## Security & Safety

### Block Dangerous Commands

Prevent destructive operations.

**Configuration:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-dangerous.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/block-dangerous.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
command=$(echo "$input" | jq -r '.parameters.command // empty')

# Define dangerous patterns
dangerous_patterns=(
  'rm -rf /'
  'rm -rf \*'
  'mkfs'
  'dd if='
  ':(){:|:&};:'  # Fork bomb
  '> /dev/sda'
  'chmod -R 777 /'
  'chown -R'
)

# Check each pattern
for pattern in "${dangerous_patterns[@]}"; do
  if [[ "$command" == *"$pattern"* ]]; then
    echo "{\"decision\": \"deny\", \"message\": \"Blocked dangerous command: $pattern\"}" >&2
    exit 2
  fi
done

# Warn on potentially dangerous commands
warning_patterns=(
  'rm -rf'
  'rm -f'
  'DROP TABLE'
  'DROP DATABASE'
  'git push --force'
  'git reset --hard'
)

for pattern in "${warning_patterns[@]}"; do
  if [[ "$command" == *"$pattern"* ]]; then
    echo "{\"decision\": \"ask\", \"message\": \"Potentially dangerous: $pattern. Continue?\"}" >&2
    exit 2
  fi
done

echo '{"decision": "allow"}'
exit 0
```

### Protect Sensitive Files

Block writes to sensitive files.

**Configuration:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/protect-sensitive.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/protect-sensitive.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

# Skip if no file
[[ -z "$file" ]] && {
  echo '{"decision": "allow"}'
  exit 0
}

# Get basename for pattern matching
basename=$(basename "$file")

# Block sensitive files
if [[ "$basename" =~ ^\.env || \
      "$basename" =~ \.pem$ || \
      "$basename" =~ \.key$ || \
      "$basename" =~ ^id_rsa || \
      "$basename" =~ secrets || \
      "$basename" =~ credentials ]]; then
  echo "{\"decision\": \"deny\", \"message\": \"Cannot modify sensitive file: $basename\"}" >&2
  exit 2
fi

# Warn on config files
if [[ "$basename" =~ config\.(json|yaml|yml|toml)$ || \
      "$file" =~ /etc/ ]]; then
  echo "{\"decision\": \"ask\", \"message\": \"Modifying configuration file. Continue?\"}" >&2
  exit 2
fi

echo '{"decision": "allow"}'
exit 0
```

### Validate File Paths

Ensure files are within project directory.

**Script (.claude/hooks/validate-path.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
tool=$(echo "$input" | jq -r '.tool')
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

# Only validate file operations
[[ "$tool" =~ ^(Write|Edit|Read)$ ]] || {
  echo '{"decision": "allow"}'
  exit 0
}

# Skip if no file
[[ -z "$file" ]] && {
  echo '{"decision": "allow"}'
  exit 0
}

# Resolve to absolute path
abs_file=$(realpath -m "$file" 2>/dev/null) || {
  echo '{"decision": "deny", "message": "Invalid file path"}' >&2
  exit 2
}

# Check if within project
if [[ "$abs_file" != "${CLAUDE_PROJECT_DIR}"* ]]; then
  echo "{\"decision\": \"deny\", \"message\": \"Path outside project: $abs_file\"}" >&2
  exit 2
fi

echo '{"decision": "allow"}'
exit 0
```

## Permission Automation

### Auto-approve Safe Operations

Reduce permission dialogs for trusted operations.

**Configuration:**

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": ".*",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/auto-approve.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/auto-approve.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
tool=$(echo "$input" | jq -r '.tool')
command=$(echo "$input" | jq -r '.parameters.command // empty')

# Auto-approve read operations
if [[ "$tool" =~ ^(Read|Glob|Grep)$ ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Auto-approve safe git commands
if [[ "$tool" == "Bash" ]]; then
  if [[ "$command" =~ ^git\ (status|log|diff|branch|show) ]]; then
    echo '{"decision": "allow"}'
    exit 0
  fi

  # Auto-approve safe npm commands
  if [[ "$command" =~ ^npm\ (list|view|search|info) ]]; then
    echo '{"decision": "allow"}'
    exit 0
  fi

  # Auto-approve ls, pwd, echo
  if [[ "$command" =~ ^(ls|pwd|echo|cat|head|tail|grep|find) ]]; then
    echo '{"decision": "allow"}'
    exit 0
  fi
fi

# Ask for everything else
echo '{"decision": "ask"}'
exit 0
```

### Auto-deny Risky Operations

Automatically block operations without prompting.

**Script (.claude/hooks/auto-deny.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
tool=$(echo "$input" | jq -r '.tool')
command=$(echo "$input" | jq -r '.parameters.command // empty')

# Block sudo operations
if [[ "$command" =~ ^sudo ]]; then
  echo '{"decision": "deny", "message": "Sudo operations not allowed"}' >&2
  exit 2
fi

# Block force push to protected branches
if [[ "$command" =~ git\ push.*--force ]]; then
  if [[ "$command" =~ (main|master|production) ]]; then
    echo '{"decision": "deny", "message": "Force push to protected branch blocked"}' >&2
    exit 2
  fi
fi

# Block npm publish
if [[ "$command" =~ ^npm\ publish ]]; then
  echo '{"decision": "deny", "message": "Use CI/CD for publishing"}' >&2
  exit 2
fi

# Continue to next hook or ask user
echo '{"decision": "ask"}'
exit 0
```

## Testing & CI Integration

### Run Tests Before Committing

Ensure tests pass before git commits.

**Configuration:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/test-before-commit.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/test-before-commit.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
command=$(echo "$input" | jq -r '.parameters.command // empty')

# Only check git commit commands
if [[ ! "$command" =~ git\ commit ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Skip for --amend (tests already passed)
if [[ "$command" =~ --amend ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

echo "Running tests before commit..." >&2

# Run tests
if npm test 2>&1 | tee /tmp/test-output.log; then
  echo "Tests passed!" >&2
  echo '{"decision": "allow"}'
  exit 0
else
  failures=$(grep -c "FAIL" /tmp/test-output.log || echo "unknown")
  echo "{\"decision\": \"ask\", \"message\": \"$failures tests failing. Commit anyway?\"}" >&2
  exit 2
fi
```

### Run Type Check Before Writes

Validate TypeScript types before file changes.

**Script (.claude/hooks/type-check.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
tool=$(echo "$input" | jq -r '.tool')
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

# Only check TypeScript files
[[ "$file" =~ \.(ts|tsx)$ ]] || {
  echo '{"decision": "allow"}'
  exit 0
}

# Skip for non-write operations
[[ "$tool" =~ ^(Write|Edit)$ ]] || {
  echo '{"decision": "allow"}'
  exit 0
}

# Run type check
if npx tsc --noEmit 2>&1 | tee /tmp/tsc-output.log; then
  echo '{"decision": "allow"}'
  exit 0
else
  errors=$(grep -c "error TS" /tmp/tsc-output.log || echo "0")
  echo "{\"decision\": \"ask\", \"message\": \"$errors type errors. Proceed?\"}" >&2
  exit 2
fi
```

## Context Injection

### Add Project Guidelines at Session Start

Inject project-specific rules and conventions.

**Configuration:**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": ".*",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/inject-guidelines.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/inject-guidelines.sh):**

```bash
#!/usr/bin/env bash
set -e

# Build context from multiple sources
context=""

# Load CLAUDE.md if exists
if [[ -f "${CLAUDE_PROJECT_DIR}/CLAUDE.md" ]]; then
  context+="# Project Documentation\n\n"
  context+=$(cat "${CLAUDE_PROJECT_DIR}/CLAUDE.md")
  context+="\n\n"
fi

# Add custom guidelines
context+="# Development Guidelines\n\n"
context+="- TypeScript with strict mode enabled\n"
context+="- Use named exports, no default exports\n"
context+="- Write tests for all features\n"
context+="- Run \`npm test\` before committing\n"
context+="- Follow Prettier formatting\n"
context+="- Use conventional commits (feat:, fix:, docs:)\n"
context+="\n"

# Add architecture notes
if [[ -f "${CLAUDE_PROJECT_DIR}/ARCHITECTURE.md" ]]; then
  context+="# Architecture\n\n"
  context+=$(cat "${CLAUDE_PROJECT_DIR}/ARCHITECTURE.md")
fi

# Output as JSON
jq -n --arg ctx "$context" '{"additionalContext": $ctx}'

exit 0
```

### Load Environment-Specific Context

Inject context based on current environment.

**Script (.claude/hooks/env-context.sh):**

```bash
#!/usr/bin/env bash
set -e

# Detect environment
if [[ -f "${CLAUDE_PROJECT_DIR}/.env.production" ]]; then
  env="production"
elif [[ -f "${CLAUDE_PROJECT_DIR}/.env.staging" ]]; then
  env="staging"
else
  env="development"
fi

context="# Environment: $env\n\n"

case "$env" in
  "production")
    context+="⚠️  PRODUCTION ENVIRONMENT\n"
    context+="- Extra caution required\n"
    context+="- Always run full test suite\n"
    context+="- Require code review before deployment\n"
    ;;
  "staging")
    context+="Staging environment for testing\n"
    context+="- Mirror of production\n"
    context+="- Safe for experiments\n"
    ;;
  "development")
    context+="Development environment\n"
    context+="- Safe for rapid iteration\n"
    ;;
esac

jq -n --arg ctx "$context" '{"additionalContext": $ctx}'

exit 0
```

## Smart Validation with LLM

### Semantic Code Review

Use LLM to evaluate code quality before writes.

**Configuration:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "prompt",
          "prompt": "Review this code change for:\n1. Code quality and best practices\n2. Potential bugs or issues\n3. Security vulnerabilities\n4. Performance concerns\n\nIf any critical issues found, return {\"decision\": \"deny\", \"message\": \"reason\"}.\nIf minor issues, return {\"decision\": \"ask\", \"message\": \"concerns\"}.\nIf code is good, return {\"decision\": \"allow\"}."
        }]
      }
    ]
  }
}
```

### Natural Language Policy Enforcement

Evaluate operations against natural language rules.

**Configuration:**

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": ".*",
        "hooks": [{
          "type": "prompt",
          "prompt": "Evaluate if this prompt requests:\n1. Destructive operations (deleting databases, force-pushing to main)\n2. Security risks (disabling auth, exposing secrets)\n3. Policy violations (bypassing reviews, skipping tests)\n\nReturn {\"decision\": \"block\", \"message\": \"reason\"} if any detected, otherwise {\"decision\": \"allow\"}."
        }]
      }
    ]
  }
}
```

## Workflow Automation

### Auto-generate Documentation

Create docs after code changes.

**Configuration:**

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/update-docs.sh"
        }]
      }
    ]
  }
}
```

**Script (.claude/hooks/update-docs.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

# Only process source files
[[ "$file" =~ \.(ts|js|py|rs|go)$ ]] || exit 0

echo "Updating documentation..." >&2

# Generate TypeDoc for TypeScript
if [[ "$file" =~ \.(ts|tsx)$ ]]; then
  npx typedoc --out docs "$file" 2>/dev/null || true
fi

# Generate Python docs
if [[ "$file" =~ \.py$ ]]; then
  pydoc-markdown > docs/$(basename "$file" .py).md 2>/dev/null || true
fi

exit 0
```

### Sync Changes to Remote

Push changes after commits.

**Script (.claude/hooks/auto-push.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
command=$(echo "$input" | jq -r '.parameters.command // empty')

# Only trigger on git commit
[[ "$command" =~ git\ commit ]] || {
  echo '{"decision": "allow"}'
  exit 0
}

# Allow the commit
echo '{"decision": "allow"}'

# Push in background (don't block commit)
(
  sleep 1
  cd "${CLAUDE_PROJECT_DIR}"
  git push 2>&1 | logger -t claude-hook
) &

exit 0
```

## Debugging & Logging

### Comprehensive Hook Logger

Log all hook executions for debugging.

**Script (.claude/hooks/logger.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
log_file="${CLAUDE_PROJECT_DIR}/.claude/hooks.log"

# Parse input
tool=$(echo "$input" | jq -r '.tool // "unknown"')
session=$(echo "$input" | jq -r '.sessionId // "unknown"')
timestamp=$(date -Iseconds)

# Log entry
log_entry="[$timestamp] Session: $session, Tool: $tool"

# Add tool-specific details
if [[ "$tool" == "Bash" ]]; then
  command=$(echo "$input" | jq -r '.parameters.command // "unknown"')
  log_entry+=", Command: $command"
elif [[ "$tool" =~ ^(Write|Edit|Read)$ ]]; then
  file=$(echo "$input" | jq -r '.parameters.file_path // "unknown"')
  log_entry+=", File: $file"
fi

# Append to log
echo "$log_entry" >> "$log_file"

# Continue with allow
echo '{"decision": "allow"}'
exit 0
```

### Performance Profiler

Measure hook execution time.

**Script (.claude/hooks/profiler.sh):**

```bash
#!/usr/bin/env bash
set -e

start_time=$(date +%s%N)

input=$(cat)

# Your hook logic here
# ...

# Calculate duration
end_time=$(date +%s%N)
duration_ms=$(( (end_time - start_time) / 1000000 ))

# Log performance
echo "Hook execution time: ${duration_ms}ms" >&2

# Output decision
echo '{"decision": "allow"}'
exit 0
```

## Plugin-Specific Hooks

### Format Code (Plugin)

Plugin hook for code formatting.

**Plugin structure:**

```text
my-format-plugin/
├── plugin.json
└── scripts/
    └── format.sh
```

**plugin.json:**

```json
{
  "name": "my-format-plugin",
  "hooks": {
    "PostToolUse": [{
      "matcher": "Write|Edit",
      "hooks": [{
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/format.sh"
      }]
    }]
  }
}
```

**scripts/format.sh:**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

[[ -z "$file" ]] && exit 0

# Load formatter config from plugin
config="${CLAUDE_PLUGIN_ROOT}/config/prettier.json"

if [[ "$file" =~ \.(ts|js|tsx|jsx)$ ]]; then
  npx prettier --config "$config" --write "$file" 2>/dev/null || true
fi

exit 0
```

## Advanced Patterns

### Conditional Hook Execution

Only run hooks in specific scenarios.

**Script (.claude/hooks/conditional.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)

# Check if in CI environment
if [[ -n "${CI:-}" ]]; then
  # Skip in CI
  echo '{"decision": "allow"}'
  exit 0
fi

# Check time of day (skip during off-hours)
hour=$(date +%H)
if [[ "$hour" -ge 22 || "$hour" -le 6 ]]; then
  # Skip validation during night
  echo '{"decision": "allow"}'
  exit 0
fi

# Run validation only during work hours
# ... validation logic ...

exit 0
```

### Cascading Hooks

Chain multiple validation steps.

**Script (.claude/hooks/cascade.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
file=$(echo "$input" | jq -r '.parameters.file_path // empty')

# Step 1: Validate syntax
if ! node -c "$file" 2>/dev/null; then
  echo '{"decision": "deny", "message": "Syntax error"}' >&2
  exit 2
fi

# Step 2: Run linter
if ! eslint "$file" 2>/dev/null; then
  echo '{"decision": "ask", "message": "Linter warnings"}' >&2
  exit 2
fi

# Step 3: Check formatting
if ! prettier --check "$file" 2>/dev/null; then
  # Auto-fix formatting
  prettier --write "$file" 2>/dev/null
fi

# All checks passed
echo '{"decision": "allow"}'
exit 0
```

### Rate Limiting

Limit expensive operations.

**Script (.claude/hooks/rate-limit.sh):**

```bash
#!/usr/bin/env bash
set -e

input=$(cat)
rate_file="/tmp/claude-rate-limit"

# Read current count
if [[ -f "$rate_file" ]]; then
  count=$(cat "$rate_file")
  timestamp=$(stat -c %Y "$rate_file")
  now=$(date +%s)

  # Reset if older than 1 minute
  if [[ $((now - timestamp)) -gt 60 ]]; then
    count=0
  fi
else
  count=0
fi

# Increment count
count=$((count + 1))
echo "$count" > "$rate_file"

# Check limit
if [[ "$count" -gt 10 ]]; then
  echo '{"decision": "deny", "message": "Rate limit exceeded (10/minute)"}' >&2
  exit 2
fi

echo '{"decision": "allow"}'
exit 0
```
