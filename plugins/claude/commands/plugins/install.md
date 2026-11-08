---
description: Install one or more plugins from the marketplace into project settings
argument-hint: '[plugin-name...]'
allowed-tools: Bash(*)
---

Install one or more plugins from the Claude plugin marketplace into the current project's settings.

Follow these steps:

1. **List available plugins**:

   - Run the helper script to get all available plugins: `bash plugins/claude/scripts/list-marketplace-plugins.sh`
   - The script outputs one line per plugin in the format: `plugin-name@marketplace-name`
   - This format is ready to use as keys in the `enabledPlugins` object

2. **Select plugins to install**:

   - If plugin names were provided as arguments (`$ARGUMENTS`), use those plugins
   - If no arguments were provided, use AskUserQuestion with `multiSelect: true` to let the user choose multiple plugins to install
   - Options should include the plugin name and description
   - Validate that all selected plugins exist in the marketplace

3. **Choose settings location**:

   - Use AskUserQuestion to ask the user where to install the plugins:
     - **Local project settings** (`.claude/settings.local.json`): Only for this project, not shared with team
     - **Shared project settings** (`.claude/settings.json`): Shared with team via version control
   - Explain the difference so the user can make an informed choice

4. **Update project settings**:

   - Based on the user's choice, use either `.claude/settings.json` or `.claude/settings.local.json`
   - Check if the settings file exists in the current working directory
   - If not, create `.claude/` directory and the settings file with an empty object `{}`
   - Read the current settings file
   - Add or update the `enabledPlugins` object to include all selected plugins
   - Each plugin should be a key in the format `"plugin-name@marketplace-name"` with a value of `true`
   - Example settings.json entry:

     ```json
     {
       "enabledPlugins": {
         "github@ungood": true,
         "nix@ungood": true,
         "claude@ungood": true
       }
     }
     ```

5. **Confirm installation and prompt restart**:

   - Inform the user that the plugins have been added to their project settings
   - List all the plugins that were added to enabledPlugins
   - **Important**: Prompt the user to restart Claude for the changes to take effect
