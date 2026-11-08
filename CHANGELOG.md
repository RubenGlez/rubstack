# Changelog

## 0.1.0 — unreleased

First version, derived from the [harness](https://github.com/RubenGlez/harness) plugin (v0.3.2) and reshaped to run the same way locally and in Claude Code cloud sessions.

- Claude Code only: Codex and OpenCode support, the installer/updater scripts, and the status line are gone. The plugin is installed through the claude.ai account.
- Project docs move from `.harness/` to `.rubstack/`; `/migrate-docs` moves existing projects.
- No global rules file: harness's `rules.md` is split into the skills that apply each rule (`_shared/git-workflow.md`, `_shared/writing.md`, `/task`, `/implement`, `/dev-plan`, `/qa`). Rules no skill applies are dropped.
- doctier is for public repos only: private repos keep `.rubstack/` as plain files, with no setup, and `/migrate-docs` drops doctier from private repos that still use it.
- Cloud sessions can read encrypted docs in public repos: the SessionStart hook installs doctier and unlocks `.rubstack/` with a dedicated key from `RUBSTACK_DOCTIER_KEY`.
- Skills that used `gh` fall back to GitHub MCP tools when `gh` is not authenticated.
- `/metrics` state moves from `~/.harness/metrics` to the `metrics-data` branch, and weekly collection runs as a cloud Routine (`skills/metrics/scripts/weekly.sh`) instead of a macOS launchd job. Cloud runs skip GitHub sources.
