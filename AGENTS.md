## MATLAB Agentic Toolkit (registered for this workspace)

The toolkit lives next to this repo: `../matlab-agentic-toolkit/` (same parent folder as this project).

**Runtime note:** MATLAB code in this repository does **not** import or depend on the toolkit. The sibling clone is used for **editor/agent integration** (skills, MCP setup, optional workflows), not for executing signal-integrity or workbench logic.

### For any coding agent

- **Skills (shared convention):** This machine has MATLAB skills linked under `~/.agents/skills/` pointing at that clone. After `git pull` in the toolkit repo, skills stay current.
- **Setup / updates:** Run the setup skill in the toolkit: `../matlab-agentic-toolkit/skills-catalog/toolkit/matlab-agentic-toolkit-setup/SKILL.md`, or follow `../matlab-agentic-toolkit/GETTING_STARTED.md`.
- **Domain work:** Prefer the skills under `../matlab-agentic-toolkit/skills-catalog/matlab-core/` (see `SKILL.md` in each folder).

### MCP (MATLAB tools)

Project configs enable the MATLAB MCP server for this workspace (Cursor, VS Code Copilot, Amp). **Codex** is already configured globally in `~/.codex/config.toml` on this machine.

If MATLAB or the MCP binary moves, update the paths in `.cursor/mcp.json`, `.vscode/mcp.json`, `.amp/settings.json`, and your global agent configs. Install the server from [MATLAB MCP Core Server releases](https://github.com/matlab/matlab-mcp-core-server/releases) if needed.
