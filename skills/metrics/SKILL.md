---
name: metrics
description: Measure traction and discoverability across all non-archived GitHub repos and their publications (npm, App Store, Play Store, web properties), judge each product against its own declared intent, score the previous run's recommendations, and issue a capped set of falsifiable new ones. Use when the user asks how their projects are doing, which repos have traction, what to double down on or kill, how their products rank in search or in AI assistants, or wants a periodic portfolio review across repos and stores.
---

# Metrics

A closed loop over the whole fleet: measure, judge, bet, then score the bet next time. Read [REFERENCE.md](REFERENCE.md) for data-source detail, the verdict rules, and the record schemas.

This is a standalone skill. It never ends with "run the next workflow skill"; it hands off per product.

## Operating contract

- **Read-only.** Never write to an analyzed repo and never open issues. The only thing this skill writes is its own state, in its state artifact (see Step 1).
- **Judge each product against its own declared intent**, from its `.rubstack/product/product.md`, and against its own history. Never rank products against each other on a normalized traction score.
- **Ownership is verified, never assumed.** A package matching a repo name may belong to someone else.
- **A missing credential is "unknown", never "zero".** Every gap is reported with its reason.
- **At most one live bet per product, ten in total.** Product and discoverability bets compete in the same pool.

## Step 1: Collect

**State** lives in the database of a private Artifact titled **rubstack metrics**, never in a git repo: rubstack is public, and the state names private repos, traffic, Search Console data and open bets. Find its URL from `RUBSTACK_METRICS_ARTIFACT` when set, otherwise with `Artifact` `action: "list"`, matching the title. Its page summarizes the stored state; its access rules let only editors read or write it, so sharing the page never exposes the data. Collections:

- `state`: documents `config` (product mapping, frozen GEO queries, `dashboard.url`) and `recommendations` (the bet ledger, schema in [REFERENCE.md](REFERENCE.md)).
- `snapshots`: one document per run, `doc_id` = its `YYYY-MM-DD` date. Each must stay under 256 KiB.

The scripts work on a local mirror at `$RUBSTACK_METRICS_HOME` (default `~/.rubstack/metrics/`), laid out the way `ArtifactData`'s `out_dir` writes it: `state/config.json`, `state/recommendations.json`, `snapshots/<date>.json`. Move data between the two through files (`out_dir` on reads, `file_path` on writes), never inline: snapshots are tens of KB each.

**Every run:**

1. **Pull.** `ArtifactData` `list` of `state` and of `snapshots` (`query.limit: 1000`), both with `out_dir: $RUBSTACK_METRICS_HOME`. Keep the `version` of each `state` document for step 4.
2. **Collect.**

   ```bash
   bash <skill>/scripts/weekly.sh
   ```

   It runs the stdlib-only collector against the mirror and prints the new snapshot's path on its last line.
3. **Push the snapshot.** `ArtifactData` `set`, collection `snapshots`, `doc_id` the date, `file_path` the printed path.
4. **Push the state** before reporting: whatever this run changes in `config` or `recommendations`, edit the mirror file and write it back with `set` and `file_path`, pinned with `if_version`. On a version conflict, pull again and redo the change.

A cloud Routine runs the same three steps every Monday. Without an authenticated `gh` (any cloud run), GitHub sources are recorded as gaps; only a local run fills in stars, releases and traffic. GitHub keeps traffic for 14 days, so tell the user when the last snapshot with traffic is more than 10 days old.

**First run only**, on the user's machine (`--init` needs `gh` to discover repos). If no artifact titled **rubstack metrics** exists, publish one: a small page that reads the store, with `capabilities` `{"db": {"rules": [{"path": "state", "read": "admin", "write": "admin"}, {"path": "snapshots", "read": "admin", "write": "admin"}]}}`. Then build the mirror. If `migration/from-harness.sh` already left state in it, use that. Otherwise:

```bash
RUBSTACK_METRICS_HOME=~/.rubstack/metrics python3 <skill>/scripts/collect.py --init      # config skeleton
RUBSTACK_METRICS_HOME=~/.rubstack/metrics python3 <skill>/scripts/collect.py --backfill  # npm and star history
```

Upload all of it with `ArtifactData` `batch` (at most 50 writes and 1 MiB per batch, so split the snapshots).

Read the snapshot. Do not re-fetch anything the collector already gathered.

## Step 2: Close the config gaps

`--init` leaves the judgment calls unset. Resolve them once, then persist to `config.json`:

- **`role`** — `product` or `support`. Support means infrastructure, assets or meta repos that exist to serve other work. They get no traction verdict, only an appendix line.
- **`sites`** — landing pages the collector could not infer.
- **`geo_queries`** — derive from the audience and problem in each product's `.rubstack/product/product.md`, present them for approval, then freeze. Changing a frozen set starts a new series: bump `geo_queries_version` and never compare across versions.

## Step 3: Score the open bets

Before measuring anything new, settle what was already predicted. For each open bet in `recommendations.json`:

1. **Was it applied?** Check its declared verification signal against observable state. Ask the user only about bets whose signal cannot be checked automatically, in one short list.
2. **Not applied and past its window twice** → `expired`, not `failed`. Ask whether to keep or drop it. A recommendation you keep not doing is itself a finding.
3. **Applied but before its evaluation date** → leave open. Judge nothing early.
4. **Applied and past its date** → compare against the written prediction. `won` or `lost`, nothing in between.
5. **Lost and reversible** → propose the reversal with the exact commit or command, and the skill to run. Never revert anything yourself.

Confounders matter: if an external event plausibly explains the movement, say so and downgrade the confidence. With one product and no control group, a met prediction is a met prediction, not proof the action caused it. Never write causal language the data cannot support.

## Step 4: Traction

For each `product` role, read its `.rubstack/product/product.md` for who it is for and what it is trying to be, then read its numbers from the snapshot against earlier snapshots.

Products whose declared purpose is a showcase are judged on audience signal, not on downloads. A product with no `product.md` is judged on intent inferred from its README, and every conclusion drawn from it is labelled low confidence with a suggestion to run `/product-plan`.

## Step 5: Discoverability

Three distinct measurements. Do not collapse them.

- **SEO** — real Search Console data per page: impressions, clicks, position, and which queries actually bring people. The collector's static page audit only explains a bad number; it never substitutes for one.
- **GEO** — run each product's frozen queries against engines with live retrieval, three times each, and record the appearance rate. Track *mentioned* and *described correctly* separately: being cited wrongly is a different failure from being ignored, and it is fixed differently.
- **ASO** — the store funnel (impressions, listing visits, installs) plus a listing audit.

Search Console, Play Console and App Store Connect need an OAuth or signed-JWT flow, so they are collected through the browser layer, not the script. See [REFERENCE.md](REFERENCE.md).

If navigating to one of these lands on a login page, that is not the same as the source being unreachable. Stop and ask the user to log in in that browser tab, then retry — do not silently skip the source and report it as unread. Only fall back to "unread this run, needs an attended login" if the user says they can't log in right now.

Label every GEO number as comparable to itself over time, never as a market position. Probing from a logged-in browser measures a personalized bubble.

## Step 6: Distribution gaps

Cross capability against presence, as its own section: a publishable package never published, an app live in one storefront but not another, a skill or MCP server absent from the registry that indexes its kind, a public repo with no release, a product whose only surface is its own README. These are usually the cheapest wins in the report, because the product already exists and only the channel is missing.

The snapshot carries two fleet-level channels for this: `skills_sh` (published agent skills and install counts) and `mcp_registry` (which of the owner's servers the curated GitHub registry lists). Both are channels where a capability the user already ships may simply be absent.

## Step 7: Verdicts and new bets

Every `product` gets exactly one label, with the numbers that justify it and a single next action: **DOUBLE DOWN / KEEP / PROMOTE / KILL / NO DATA**. No hedging. `NO DATA` must name what to start measuring.

`KILL` is unavailable for anything under 90 days from its first publication. A young product with no traction is young, not dead.

Then issue new bets, at most one per product and ten in total, chosen by expected impact across both product and discoverability work. A bet that cannot state a metric, a number and a date is not a bet; drop it or sharpen it. Findings that affect the portfolio, and therefore every product hosted on it, outrank single-product fixes.

**A bet must name an action the user can actually take.** Absence from a curated or invite-only list is somebody else's decision, not a gap to close; verify a channel is open to submissions before recommending it. Confirm the same before calling anything a distribution gap in Step 6.

## Step 8: Report

The portfolio has a dual role: it is a product with its own `product.md` and the distribution channel for every project page hosted on it. Give it its own section, and mark shared-surface findings as multiplier levers.

Publish an HTML dashboard as a private Artifact. `config.json` stores `dashboard.url` from the first run; pass it as `url` on every later publish so the panel stays at one address instead of minting a new one each month. Load the `artifact-design` and `dataviz` skills before building it. It must include the bet ledger and the skill's own hit rate, so a run that keeps recommending badly is visible as such.

Write the dashboard's prose in Spanish — headline, dek, tile labels, table copy, bet descriptions, notes. Keep product names, URLs, and literal data-model tokens (bet `kind` values like `seo`/`distribution`/`geo`/`product`, the `product.md` filename, verdict labels `DOUBLE DOWN`/`PROMOTE`/`KEEP`/`KILL`/`NO DATA`) as-is rather than translated, since they're fixed vocabulary shared with `recommendations.json` and the verdict rules above. Use Spanish decimal commas and thousands spacing for numbers (`25,2`, `16 830`).

In the chat, leave a summary of about five lines: what moved, what was settled, what is now live. Nothing else.
