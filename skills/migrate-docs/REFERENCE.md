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

## Tracking an untracked `.rubstack/` in a private repo

1. `rm -rf .rubstack/.base` — stale seed snapshot from old tooling, if present.
2. Remove any standalone `.rubstack/` (or `.harness/`) line from `.gitignore`, then run "Setup" in [../_shared/doc-store.md](../_shared/doc-store.md) (plain mode).
3. `git add .gitignore .rubstack/`, refresh the doc index ([../_shared/doc-store.md](../_shared/doc-store.md#refresh-the-doc-index-in-agentsmd)) and `git add AGENTS.md`.
4. `git commit -m "chore: track .rubstack/ docs"`

---

## Adopting doctier on a public repo with an untracked `.rubstack/`

The docs already exist on disk; the goal is to start tracking them encrypted without ever committing plaintext.

1. `rm -rf .rubstack/.base` — stale seed snapshot from old tooling, if present.
2. Run the doctier bootstrap in [../_shared/doctier-bootstrap.md](../_shared/doctier-bootstrap.md) (write the manifest, then `doctier init`, then `doctier grant`), including removing any standalone `.rubstack/` line from `.gitignore`.
3. `doctier check` — must pass before tracking anything.
4. `git add .doctier.yml .doctier/ .gitattributes .gitignore .github/CODEOWNERS .rubstack/`
5. Verify encryption: `git show :.rubstack/<any-file> | head -1` must be an age/doctier envelope, not your prose. If it is plaintext, the filter is not active — stop, `git reset`, and re-run `doctier init` before trying again.
6. `doctier agents --write && git add AGENTS.md`
7. `git commit -m "chore: adopt doctier; track .rubstack/ encrypted"`

---

## Moving a harness `.harness/` store

For projects set up with the harness plugin. The docs are already in the right shape; only the path changes, and in private repos the encryption goes away.

1. Make sure the working tree holds plaintext: `head -1 .harness/<any-file>` must be prose, not an age envelope. If it is ciphertext, run `doctier unlock` (needs a granted key; in a cloud session, `RUBSTACK_DOCTIER_KEY` — see the README). Never move ciphertext you cannot decrypt.
2. If `.harness/` was never tracked (`git ls-files .harness` is empty), `mv .harness .rubstack` and switch to the matching untracked-store recipe above. Otherwise `git mv .harness .rubstack`.
3. **Private repo:** follow "Dropping doctier from a private repo" below from its step 2, then come back to step 5 here.
4. **Public repo:** in `.doctier.yml`, change `".harness/**"` to `".rubstack/**"` (a policy-file change: call it out), run `doctier init` to re-sync the managed `.gitattributes` and `.gitignore` blocks, then `git add --renormalize .rubstack && git add .doctier.yml .gitattributes .gitignore`. Verify `git show :.rubstack/<any-file> | head -1` is an age envelope; if it is plaintext, stop, `git reset`, and re-run `doctier init`.
5. Update every remaining `.harness/` reference outside the store (`AGENTS.md`, `CLAUDE.md`, README, CI): `grep -rn '\.harness' --exclude-dir=.git .` must come back empty. Then refresh the doc index ([../_shared/doc-store.md](../_shared/doc-store.md#refresh-the-doc-index-in-agentsmd)) and `git add AGENTS.md`.
6. `git commit -m "chore: move workflow docs from .harness/ to .rubstack/"`

---

## Dropping doctier from a private repo

Private repos keep `.rubstack/` in plaintext. Older commits keep their ciphertext; that is harmless and needs no rewrite.

1. Make sure the working tree holds plaintext: `head -1 .rubstack/<any-file>` must be prose. If it is ciphertext, run `doctier unlock` first.
2. Remove the managed doctier block (`# doctier:begin` … `# doctier:end`) from `.gitattributes`; delete the file if nothing else is left in it.
3. `git rm -r -q .doctier.yml .doctier/`
4. In `.gitignore`, replace the doctier block with the rubstack block from "Setup" in [../_shared/doc-store.md](../_shared/doc-store.md) (the prototype/spike lines; drop `.doctier/trash/`).
5. In `.github/CODEOWNERS`, remove the entries for `.doctier.yml`, `.doctier/` and `.gitattributes` and their comment; delete the file if nothing else is left.
6. Clean this clone's local git setup, which doctier wrote outside git: `git config --remove-section filter.doctier`, the same for `diff.doctier` and `merge.doctier` (ignore "no such section"), and delete `.git/hooks/pre-commit`, `pre-push` and `post-merge` if they call doctier. Tell the user that other clones need the same cleanup (or a fresh clone): a leftover doctier pre-commit hook fails once `.doctier.yml` is gone.
7. Store the docs as plaintext: `git add --renormalize .rubstack && git add -A .rubstack .gitattributes .gitignore .github`
8. Verify: `git show :.rubstack/<any-file> | head -1` must be prose. If it is still an age envelope, the doctier attributes are still in effect — re-check step 2.
9. In `AGENTS.md`, replace the `<!-- doctier:begin -->` block with the plain-mode doc index ([../_shared/doc-store.md](../_shared/doc-store.md#refresh-the-doc-index-in-agentsmd)), then `git add AGENTS.md`.
10. `git commit -m "chore: drop doctier — .rubstack/ is plaintext in this private repo"` (skip when called from the `.harness/` move, which commits once at the end).
