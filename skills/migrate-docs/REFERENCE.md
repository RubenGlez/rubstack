# Migrate Docs — Reference

## Rubstack File Templates

Migrate each file's content into the canonical template for its destination — do not keep a second copy of those templates here (they drift). The owning skills define them; transform the source into those exact sections, preserving ALL information (if something doesn't fit, add it under the closest section; never invent content for an empty one):

| Destination | Canonical template |
|---|---|
| `.rubstack/product/idea.md` | [`/ideate`](../ideate/SKILL.md) — "Write `.rubstack/product/idea.md`" |
| `.rubstack/product/{product,roadmap,competitors,ux,CONTEXT}.md` | [`/product-plan` REFERENCE](../product-plan/REFERENCE.md) — "Document Templates" |
| `.rubstack/engineering/{architecture,implementation-plan}.md`, `features/[slug].md`, `adr/NNNN-*.md`, root `DESIGN.md` | [`/dev-plan` REFERENCE](../dev-plan/REFERENCE.md) — "Document Templates" |
| `.rubstack/qa/report.md` | [`/qa` REFERENCE](../qa/REFERENCE.md) — "Report Template" |

### DESIGN.md: public tokens vs. migrated rationale

Use `.rubstack/product/ux.md` for internal design direction: workflow rationale, interaction model, design principles, creative north star, and UX decisions. If an existing `DESIGN.md` is mostly prose about how the product should feel or behave, migrate that content here.

Keep root `DESIGN.md` only for public design-token specifications: exact color, typography, spacing, radius, and component token values plus contributor-facing implementation rules. If a design file mixes token values with UX rationale, split it instead of preserving the mixed file.

---

## Adopting doctier on a repo with an existing (gitignored) `.rubstack/`

For projects whose `.rubstack/` predates git tracking. The docs already exist on disk; the goal is to start tracking them encrypted without ever committing plaintext.

1. `rm -rf .rubstack/.base` — stale seed snapshot left by the old worktree hook, if present.
2. Run the doctier bootstrap in [../_shared/doctier-bootstrap.md](../_shared/doctier-bootstrap.md) (write the manifest, then `doctier init`, then `doctier grant`), including removing the legacy standalone `.rubstack/` line from `.gitignore`.
3. `doctier check` — must pass before tracking anything.
4. `git add .doctier.yml .doctier/ .gitattributes .gitignore .github/CODEOWNERS .rubstack/`
5. Verify encryption: `git show :.rubstack/<any-file> | head -1` must be an age/doctier envelope, not your prose. If it is plaintext, the filter is not active — stop, `git reset`, and re-run `doctier init` before trying again.
6. `doctier agents --write && git add AGENTS.md` — refresh the doc index so agents know which `.rubstack/` docs to read (creates the managed block, and the file itself if the repo has no `AGENTS.md`).
7. `git commit -m "chore: adopt doctier; track .rubstack/ encrypted"`
8. Old linked worktrees still carry seeded plaintext copies of `.rubstack/` — remove and recreate them so they use the tracked docs. (To refresh in place: run `doctier unlock` inside the worktree to re-decrypt the tracked docs over the stale copies.)

---

## Migrating a harness `.harness/` store to `.rubstack/`

For projects set up with the harness plugin. The docs are already in the right shape; only the store's path changes, and they must stay encrypted the whole way.

1. Make sure the working tree holds plaintext: `head -1 .harness/<any-file>` must be prose, not an age envelope. If it is ciphertext, run `doctier unlock` (needs a granted key; in a cloud session, see the `RUBSTACK_DOCTIER_KEY` notes in [../_shared/doctier-bootstrap.md](../_shared/doctier-bootstrap.md)). Never move ciphertext you cannot decrypt.
2. Move the store: `git mv .harness .rubstack` (or plain `mv` if `.harness/` was never tracked — then follow the pre-doctier recipe above instead of the steps below).
3. In `.doctier.yml`, change the `".harness/**"` path to `".rubstack/**"`. This is a policy-file change: it is expected here, but call it out to the user as a security-relevant diff.
4. `doctier init` — re-syncs the managed `.gitattributes` and `.gitignore` blocks to the new path.
5. `git add --renormalize .rubstack && git add .doctier.yml .gitattributes .gitignore`
6. Verify encryption: `git show :.rubstack/<any-file> | head -1` must be an age/doctier envelope. If it is plaintext, stop, `git reset`, and re-run `doctier init`.
7. Update every remaining `.harness/` reference outside the store (`AGENTS.md`, `CLAUDE.md`, README, CI): `grep -rn '\.harness' --exclude-dir=.git .` must come back empty. Then `doctier agents --write && git add AGENTS.md`.
8. `git commit -m "chore: move workflow docs from .harness/ to .rubstack/"`
