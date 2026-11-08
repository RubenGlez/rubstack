# rubstack

A Claude Code plugin, distributed through a git marketplace (this repo) and installed through the claude.ai account, so the same plugin loads on the user's machine and in Claude Code cloud sessions. There is no installer script and no build step.

**Everything must work in both places.** A cloud session is a fresh Linux container: no `~/.claude/CLAUDE.md`, no SSH keys, no Homebrew, `gh` unauthenticated, nothing in `$HOME` that the plugin did not create. So:

- Global rules live in `rules/rules.md` and reach the session through the SessionStart hook's stdout, not through `~/.claude/CLAUDE.md`.
- GitHub access goes through `skills/_shared/github-access.md`: `gh` when authenticated, GitHub MCP tools otherwise.
- Hooks are bash + `jq` + `python3` only, and every hook exits 0 unless it is deliberately blocking a tool call.
- Nothing macOS-only (launchd, `pbcopy`, `~/Library`); `tests/smoke.sh` enforces it.

**Doc store.** Skills keep project docs in `.rubstack/`, always tracked in git. Private repos store them as plain files and never use doctier; public repos encrypt them with doctier. `skills/_shared/doc-store.md` is the single place that decides the mode, sets it up and refreshes the AGENTS.md doc index; skills must not call doctier directly (`tests/smoke.sh` enforces it). In a cloud session the SessionStart hook decrypts a public repo's docs when `RUBSTACK_DOCTIER_KEY` (a dedicated, base64-encoded ed25519 key granted with `doctier grant`) is set on the environment. Projects still on the harness layout (`.harness/`) move with `/migrate-docs`.

**Single writer per `.rubstack/` file.** `/implement` subagents read `.rubstack/` but never write it; the orchestrator is the sole writer and commits doc changes before spawning worktrees and after merging.

**Verification contract.** `/implement` slices are verified by static checks only (typecheck, build, lint). Behavioral verification is deferred to `/qa` by design. Do not add behavioral verification to subagent prompts.

**Tests.** `bash tests/smoke.sh` covers the manifests, skill structure and links, and every hook's behavior (doctier is stubbed). CI also runs ShellCheck.

## Release

Bump `version` in `.claude-plugin/plugin.json`, add a `CHANGELOG.md` entry, commit, tag `vX.Y.Z` (annotated), and push branch and tag. Accounts that added this repo as a marketplace on claude.ai pick the new version up on their next session (with "Sync automatically" on, or after "Check for updates").
