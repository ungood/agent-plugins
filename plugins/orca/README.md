# orca

Orca's own agent skills, from [stablyai/orca](https://github.com/stablyai/orca/tree/main/skills) at commit `65412f3f`.

Each `SKILL.md` is Orca's discovery stub: it runs `orca skills get <name>` to load the guide that matches the installed
Orca. So the content stays current with your Orca, and these copies only need updating if Orca renames a skill or
changes a stub.

They're copied, not fetched, because Claude Code can't load a plugin from a repo folder that has no
`.claude-plugin/plugin.json`, and stablyai/orca's `skills/` folder has none.
