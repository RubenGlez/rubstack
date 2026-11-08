# Writing docs

Rules for any skill that writes or updates documentation: README, CHANGELOG, AGENTS.md, DESIGN.md, `.rubstack/` docs, release notes, announcements.

**Style**
- Simple language and a casual tone. No em-dashes; use commas or semicolons.
- Clear and direct; no intros or outros.
- Write as a human author would: no internal reasoning, conversation context, or agent decision-making.

**What to document**
- After a significant change (new feature, API or config change, removed functionality), update the docs that describe it: README files, comments that describe behavior, `docs/` or wiki directories.
- Keep existing docs accurate; don't add new doc files unless asked.
- Document durable, non-obvious facts (human decisions, constraints, setup assumptions, workflow conventions), never what can be read from the code.
- Say each thing once; don't duplicate what another doc already covers.

**AGENTS.md and CLAUDE.md**
- `AGENTS.md` is the canonical agent-facing doc for shared project context. Keep it minimal: only durable facts that can't be inferred from the code, manifests, or `.rubstack/` docs; when something would grow it, put the detail in the relevant `.rubstack/` doc instead.
- A project's `CLAUDE.md` contains only `@AGENTS.md`, so every agent reads the same source.
