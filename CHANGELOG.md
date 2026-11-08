# Changelog

## 0.1.0 — unreleased

First version, derived from the [harness](https://github.com/RubenGlez/harness) plugin (v0.3.2) and reshaped to run the same way locally and in Claude Code cloud sessions.

- Claude Code only: Codex and OpenCode support, the installer/updater scripts, and the status line are gone. The plugin is installed through the claude.ai account.
- Project docs move from `.harness/` to `.rubstack/`; `/migrate-docs` moves existing projects.
- Global rules are injected by the SessionStart hook instead of being written to `~/.claude/CLAUDE.md`.
- Cloud sessions can read encrypted docs: the SessionStart hook installs doctier and unlocks `.rubstack/` with a dedicated key from `RUBSTACK_DOCTIER_KEY`.
- Skills that used `gh` fall back to GitHub MCP tools when `gh` is not authenticated.
