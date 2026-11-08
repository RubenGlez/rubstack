# GitHub access

rubstack runs both on your machine and in Claude Code cloud sessions, and GitHub access differs between them. Pick the route once per run:

```bash
gh auth status >/dev/null 2>&1 && echo gh || echo mcp
```

- **`gh`** — the CLI is authenticated (normally on your machine). Use the `gh` commands the skill names.
- **`mcp`** — no authenticated CLI (normally a cloud session, where `gh` can only search). Use the GitHub MCP tools (`mcp__github__*`; load them with ToolSearch if they are deferred). Do not ask the user to authenticate `gh` in a cloud session.

| Need | `gh` | GitHub MCP |
|---|---|---|
| Who am I | `gh api user --jq .login` | `get_me` |
| List issues | `gh issue list` | `list_issues` |
| PR checks before merging | `gh pr checks <n> --watch --fail-fast` | `pull_request_read` (check runs / status), or `subscribe_pr_activity` and wait for the CI event |
| Create / update a PR | `gh pr create` / `gh pr edit` | `create_pull_request` / `update_pull_request` |
| Read a file at a ref | `gh api repos/{o}/{r}/contents/...` | `get_file_contents` |
| Releases and tags | `gh release list` | `list_releases`, `list_tags` |
| Search code, issues, repos | `gh search ...` | `gh api -X GET search/...` (search still works in cloud sessions) |
| List my repos | `gh repo list <login> --json ...` | `list_repos` (claude-code-remote) |
| Endpoints with no MCP tool (Dependabot alerts, advisories, traffic) | `gh api ...` | Not available — say which step was skipped and why; never invent the data |

**Scope in cloud sessions.** MCP tools only reach repositories attached to the session. A skill that sweeps many repos (fleet mode) lists them with `list_repos`, then attaches each one it must clone or write to with `add_repo` before working on it. If attaching is refused, record the repo as skipped with the reason.
