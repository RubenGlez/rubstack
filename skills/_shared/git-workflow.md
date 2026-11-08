# Git workflow

Every skill that commits, pushes or opens a pull request follows these rules.

- Never push to the default branch unless the user explicitly asks; work on a branch and open a PR. A `/ship` release is that explicit ask for its version bump and tag.
- Never add `Co-Authored-By` lines to commit messages or PR descriptions.
- Merge a PR only after its checks pass: `gh pr checks <number> --watch --fail-fast`, or the GitHub MCP route in a cloud session ([github-access.md](github-access.md)). Never use `gh pr merge --admin` or `git push --no-verify`.
- PR bodies have three sections, brief and without preamble:
  - `## Summary`: the smallest visual that makes the change clear (a `diff` of a file or call tree, pseudocode, a Mermaid diagram), with a line or two of text.
  - `## Evidence`: before and after (a screenshot for visual changes, otherwise the test or command that failed and now passes).
  - `## Merge danger`: one-way or two-way door (can it be rolled back cheaply?) and the blast radius (who or what could break).
