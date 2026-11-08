#!/usr/bin/env bash
# Show rubstack workflow state at session start.
# SessionStart — no stdin. Exits 0 always.

DOCS=".rubstack"

if [ -d .harness ] && [ ! -d "$DOCS" ]; then
  echo "rubstack: this repo still uses the harness layout (.harness/) — run /migrate-docs to move it to .rubstack/"
  exit 0
fi
[ ! -d "$DOCS" ] && exit 0

echo "┌─ rubstack ──────────────────────────────────────────────┐"

# Feature counts
features_dir="$DOCS/engineering/features"
if [ -d "$features_dir" ] && ls "$features_dir"/*.md &>/dev/null; then
  total=$(ls "$features_dir"/*.md | wc -l | tr -d ' ')
  done_count=$(grep -rl '\*\*Status\*\*: done' "$features_dir" 2>/dev/null | wc -l | tr -d ' ')
  blocked_count=$(grep -rl '\*\*Status\*\*: blocked' "$features_dir" 2>/dev/null | wc -l | tr -d ' ')
  planned_count=$((total - done_count - blocked_count))
  echo "│  Features : ${done_count} done · ${planned_count} planned · ${blocked_count} blocked"
fi

# Last QA
if [ -f "$DOCS/qa/report.md" ]; then
  qa_line=$(grep -m1 "^# QA Report" "$DOCS/qa/report.md")
  if [ -n "$qa_line" ]; then
    qa_date=$(echo "$qa_line" | sed 's/^# QA Report\( — \)\{0,1\}//')
    echo "│  Last QA : ${qa_date:-present}"
    # Latest report is prepended, so the first "Outstanding issues:" is the newest.
    open_issues=$(grep -m1 'Outstanding issues:' "$DOCS/qa/report.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ "${open_issues:-0}" -gt 0 ] && echo "│  Open issues : $open_issues"
  fi
fi

# Doctier adoption — .rubstack/ should be git-tracked (encrypted)
if git rev-parse --is-inside-work-tree &>/dev/null; then
  if git check-ignore -q "$DOCS" 2>/dev/null || [ -z "$(git ls-files "$DOCS" 2>/dev/null)" ]; then
    echo "│  ⚠ .rubstack/ not git-tracked — run /migrate-docs to adopt doctier"
  fi
fi

echo "└─────────────────────────────────────────────────────────┘"
exit 0
