# Doc store: `.rubstack/`

Every workflow skill keeps internal docs (product vision, competitors, specs, ADRs, QA reports) under `.rubstack/`, tracked in git so they are backed up, merged, and visible in every worktree. How they are stored depends on who can read the repository:

| Repo | Mode | `.rubstack/` in git | doctier |
|---|---|---|---|
| Private | **plain** | Plaintext | Not used. No `.doctier.yml` |
| Public | **encrypted** | age-encrypted blobs | Required: [doctier-bootstrap.md](doctier-bootstrap.md) |

Encryption only exists to keep business strategy and competitor research out of public repos. In a private repo it adds nothing but friction, so it is never used there.

**Which mode is this repo in?** `[ -f .doctier.yml ] && echo encrypted || echo plain`. Skills branch on that file, not on a fresh visibility lookup.

## Setup (once per repo)

Run this before writing the first `.rubstack/` doc. Skip it if `.rubstack/` is already tracked (`git ls-files .rubstack` is not empty).

1. **Find the visibility.** With `gh` (see [github-access.md](github-access.md)): `gh repo view --json visibility -q .visibility`. In a cloud session: `gh api -X GET search/repositories -f q="repo:<owner>/<name>" --jq '.items[0].private'`. If the repo has no remote yet, ask the user whether it will be public; default to plain.
2. **Public → encrypted mode.** Run [doctier-bootstrap.md](doctier-bootstrap.md) and stop here.
3. **Private → plain mode.** Make sure prototype code can never be committed. Add this block to `.gitignore` if it is missing:

   ```gitignore
   # rubstack:begin — prototype/spike code is throwaway: never committed
   **/_prototype-*
   **/_spike/**
   # rubstack:end
   ```

   Then `git add .gitignore`. The docs themselves are committed as plain files by the calling skill.

## Refresh the doc index in AGENTS.md

Skills that write `.rubstack/` docs end by refreshing the index that tells agents which docs to read, then committing it together with the docs.

- **Encrypted mode:** `doctier agents --write` (it maintains the block between `<!-- doctier:begin -->` and `<!-- doctier:end -->`).
- **Plain mode:** maintain this block yourself in `AGENTS.md` (create the file if the repo has none), listing every file under `.rubstack/` with a few words on what it holds. Rewrite the whole block each time from `git ls-files .rubstack` plus any new files; never edit text outside it.

  ```markdown
  <!-- rubstack:docs:begin — managed by rubstack skills, do not edit by hand -->
  Read these for project context:

  - `.rubstack/product/product.md` — audience, positioning, features
  - `.rubstack/engineering/architecture.md` — stack and system design
  <!-- rubstack:docs:end -->
  ```

## Changing visibility later

- **Private → public.** Every past commit holds the docs in plaintext, so encrypting from now on is not enough. Before the repo goes public, tell the user: either publish a fresh repository without that history, or remove `.rubstack/` from history (`git filter-repo --path .rubstack --invert-paths`) and then switch to encrypted mode with [doctier-bootstrap.md](doctier-bootstrap.md). Never flip a repo public with plaintext docs in its history.
- **Public → private, or a private repo still on doctier.** Switch to plain mode with "Dropping doctier from a private repo" in [../migrate-docs/REFERENCE.md](../migrate-docs/REFERENCE.md).
