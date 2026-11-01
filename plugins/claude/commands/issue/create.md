---
description: Report an issue to the ungood/agent-plugins plugin marketplace
allowed-tools: Bash(gh:*)
argument-hint: '[title]'
---

Report an issue to the ungood/agent-plugins plugin marketplace repository.

Follow these steps:

1. **Gather issue information from the user**:

   - If the issue title is not provided as the argument to this command, ask the user for one.
   - Ask for a detailed description of the issue
   - If the user mentions they're having a problem, ask them to include steps to reproduce

2. **Create the issue in the marketplace repository**:

   - Use `gh issue create` with the `-R` flag to target the marketplace repository `ungood/agent-plugins`
   - Use HEREDOC format for multiline bodies
   - Example:
     ```bash
     gh issue create -R ungood/agent-plugins --title "Issue title" --body "$(cat <<'EOF'
     Issue description here
     EOF
     )"
     ```

3. **Confirm creation**:

   - Show the user the issue URL returned by gh
   - Thank them for reporting the issue
