#!/usr/bin/env bash
# Smoke tests for the rubstack plugin: manifest, skills, and hooks.
# Runs in isolated temp dirs — nothing in your real HOME is touched.
#
# Usage: bash tests/smoke.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$ROOT/scripts/hooks"

PASS=0; FAIL=0
CLEANUP_DIRS=()
trap 'rm -rf "${CLEANUP_DIRS[@]:-}"' EXIT

_green() { printf '\033[32m%s\033[0m' "$*"; }
_red()   { printf '\033[31m%s\033[0m' "$*"; }
pass() { printf '  %s  %s\n' "$(_green ✓)" "$1"; PASS=$((PASS+1)); }
fail() { printf '  %s  %s\n' "$(_red   ✗)" "$1"; FAIL=$((FAIL+1)); }
section() { echo ""; echo "$1"; printf '─%.0s' $(seq 1 ${#1}); echo; }
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}
tmpdir() { local d; d=$(mktemp -d); CLEANUP_DIRS+=("$d"); echo "$d"; }

# Feed a Bash tool call to a PreToolUse hook; returns the hook's exit code.
bash_hook() { printf '%s' "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$2")}}" | bash "$HOOKS/$1" 2>/dev/null; }

# ── 1. Manifests ───────────────────────────────────────────────────────────────

section "1. Manifests"

t_json_valid() { python3 -c "import json,sys; [json.load(open(f)) for f in sys.argv[1:]]" \
  "$ROOT/.claude-plugin/plugin.json" "$ROOT/.claude-plugin/marketplace.json"; }

t_names_match() {
  python3 - "$ROOT" <<'PY'
import json, sys
from pathlib import Path
r = Path(sys.argv[1]) / '.claude-plugin'
p = json.loads((r / 'plugin.json').read_text())
m = json.loads((r / 'marketplace.json').read_text())
assert p['name'] == m['name'] == m['plugins'][0]['name'] == 'rubstack'
PY
}

t_hook_scripts_exist() {
  python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path
root = Path(sys.argv[1])
plugin = json.loads((root / '.claude-plugin' / 'plugin.json').read_text())
for entries in plugin['hooks'].values():
    for e in entries:
        for h in e['hooks']:
            m = re.search(r'scripts/hooks/(\S+\.sh)', h['command'])
            assert m and (root / 'scripts/hooks' / m.group(1)).exists(), h['command']
PY
}

check "plugin.json and marketplace.json are valid JSON" t_json_valid
check "Plugin and marketplace are both named rubstack"  t_names_match
check "Every hook command points at an existing script" t_hook_scripts_exist

# ── 2. Skills ──────────────────────────────────────────────────────────────────

section "2. Skills"

t_frontmatter() {
  python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path
for p in Path(sys.argv[1], 'skills').rglob('SKILL.md'):
    head = p.read_text().split('---')[1]
    assert 'name:' in head and 'description:' in head, p
PY
}

t_workflow_chain() {
  for s in ideate product-plan dev-plan prototype implement qa update-docs ship; do
    [ -f "$ROOT/skills/$s/SKILL.md" ] || return 1
  done
}

t_relative_links_resolve() {
  python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
bad = []
for md in Path(sys.argv[1], 'skills').rglob('*.md'):
    text = re.sub(r'```.*?```', '', md.read_text(), flags=re.S)  # skip example templates
    for target in re.findall(r'\]\(([^)#\s]+\.md)(?:#[^)]*)?\)', text):
        if target.startswith('http'):
            continue
        if not (md.parent / target).resolve().exists():
            bad.append(f'{md}: {target}')
if bad:
    print('\n'.join(bad)); sys.exit(1)
PY
}

# Claude Code only, and the doc store is .rubstack/. .harness may only appear
# in the migration itself or in lines that send the user to /migrate-docs.
t_no_stale_refs() {
  ! grep -rniE 'codex|opencode|runtime-parallelism|update\.sh|setup\.sh' "$ROOT/skills" "$ROOT/scripts" \
  && ! grep -rn '\.harness' "$ROOT/skills" "$ROOT/scripts" \
       | grep -v -e 'skills/migrate-docs/' -e 'migrate-docs' -e 'scripts/hooks/rubstack-status.sh'
}

t_no_macos_only() { ! grep -rnE 'launchctl|launchd|pbcopy|osascript|/Library/' "$ROOT/skills" "$ROOT/scripts"; }

# doctier is for public repos only: skills must reach it through doc-store.md,
# never call it unconditionally.
t_doctier_only_via_doc_store() {
  ! grep -rln 'doctier agents --write\|doctier-bootstrap.md' "$ROOT/skills" \
      | grep -v -e '_shared/doc-store.md' -e '_shared/doctier-bootstrap.md' -e 'migrate-docs/REFERENCE.md'
}

check "Every SKILL.md has name and description"        t_frontmatter
check "Skills reach doctier only through doc-store.md" t_doctier_only_via_doc_store
check "Workflow chain skills all exist"                t_workflow_chain
check "Relative .md links in skills resolve"           t_relative_links_resolve
check "No Codex/OpenCode/installer or stale .harness refs" t_no_stale_refs
check "No macOS-only commands in skills or hooks"      t_no_macos_only

# ── 3. Guard hooks ─────────────────────────────────────────────────────────────

section "3. Guard hooks"

t_blocks_force_push() { ! bash_hook block-dangerous-git.sh 'git push --force origin main'; }
t_blocks_reset_hard() { ! bash_hook block-dangerous-git.sh 'git reset --hard HEAD~1'; }
t_allows_push()       { bash_hook block-dangerous-git.sh 'git push -u origin feature'; }
t_blocks_spike()      { ! bash_hook block-prototype-commit.sh 'git add _spike/x.ts && git commit -m wip'; }
t_allows_commit()     { local d; d=$(tmpdir); (cd "$d" && git init -q && bash_hook block-prototype-commit.sh 'git commit -m ok'); }

check "Blocks git push --force"           t_blocks_force_push
check "Blocks git reset --hard"           t_blocks_reset_hard
check "Allows a normal git push"          t_allows_push
check "Blocks committing _spike/ code"    t_blocks_spike
check "Allows an ordinary commit"         t_allows_commit

# ── 4. SessionStart hook ───────────────────────────────────────────────────────

section "4. SessionStart hook"

# Run session-start.sh in a project dir with a fake HOME and a PATH whose
# doctier is a stub that records its calls and "decrypts" .rubstack/.
run_session_start() {
  local proj="$1"; shift
  env -i PATH="$STUB_BIN:/usr/bin:/bin" HOME="$FAKE_HOME" \
    CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$proj" CLAUDE_ENV_FILE="$FAKE_HOME/env" "$@" \
    bash "$HOOKS/session-start.sh"
}

STUB_BIN=$(tmpdir); FAKE_HOME=$(tmpdir)
cat > "$STUB_BIN/doctier" <<'STUB'
#!/usr/bin/env bash
echo "$* key=${DOCTIER_SSH_KEY:-}" >> "$HOME/doctier.log"
if [ "$1" = unlock ]; then
  for f in $(git ls-files .rubstack); do echo "plaintext" > "$f"; done
fi
STUB
chmod +x "$STUB_BIN/doctier"

new_project() {
  local d; d=$(tmpdir)
  (cd "$d" && git init -q && mkdir -p .rubstack/qa && touch .doctier.yml \
    && printf -- '-----BEGIN AGE ENCRYPTED FILE-----\nxx\n' > .rubstack/qa/report.md \
    && git add -A && git -c user.email=t@t -c user.name=t commit -qm init)
  echo "$d"
}
FAKE_KEY=$(printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----\n' | base64 | tr -d '\n')

# Rules live in the skills that apply them; nothing global is injected.
t_no_global_rules() { [ ! -e "$ROOT/rules" ] && local out && out=$(run_session_start "$(tmpdir)") && [ -z "$out" ]; }
t_no_key_no_doctier() {
  rm -f "$FAKE_HOME/doctier.log"; local p; p=$(new_project)
  run_session_start "$p" >/dev/null; [ ! -f "$FAKE_HOME/doctier.log" ]
}
t_key_unlocks() {
  rm -f "$FAKE_HOME/doctier.log" "$FAKE_HOME/env"; local p; p=$(new_project)
  run_session_start "$p" RUBSTACK_DOCTIER_KEY="$FAKE_KEY" | grep -q 'decrypted .rubstack/' \
    && grep -q '^unlock key=.*rubstack_doctier' "$FAKE_HOME/doctier.log" \
    && grep -q 'DOCTIER_SSH_KEY' "$FAKE_HOME/env" \
    && [ "$(stat -c %a "$FAKE_HOME/.ssh/rubstack_doctier")" = 600 ] \
    && grep -q plaintext "$p/.rubstack/qa/report.md"
}
t_bad_key_reported() {
  rm -f "$FAKE_HOME/.ssh/rubstack_doctier"; local p; p=$(new_project)
  run_session_start "$p" RUBSTACK_DOCTIER_KEY="bm90LWEta2V5" | grep -q 'not a base64-encoded private key'
}
t_legacy_layout() {
  local d; d=$(tmpdir); mkdir -p "$d/.harness"
  run_session_start "$d" | grep -q 'run /migrate-docs'
}
t_always_exit_0() { run_session_start /nonexistent >/dev/null; }

check "Injects no global rules (empty output outside a project)" t_no_global_rules
check "Without RUBSTACK_DOCTIER_KEY, doctier is untouched" t_no_key_no_doctier
check "With the key, writes it 0600 and unlocks .rubstack/" t_key_unlocks
check "Reports a malformed key"                          t_bad_key_reported
check "Points legacy .harness/ repos at /migrate-docs"   t_legacy_layout
check "Exits 0 even when the project dir is missing"     t_always_exit_0

# ── Summary ────────────────────────────────────────────────────────────────────

echo ""
echo "──────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo "  $((PASS+FAIL)) tests: $(_green "all $PASS passed")"
else
  echo "  $((PASS+FAIL)) tests: $(_red "$FAIL failed"), $PASS passed"
  exit 1
fi
