#!/usr/bin/env bash
# SessionStart: everything rubstack needs at the top of a session, local or cloud.
#   1. Global rules → stdout, which Claude Code adds to the session context.
#      (A plugin can't write ~/.claude/CLAUDE.md, and cloud sessions never see it.)
#   2. Cloud doc access: if RUBSTACK_DOCTIER_KEY is set, install doctier when
#      missing, write the key, and decrypt .rubstack/ in the project.
#   3. Workflow status for the project.
# Never blocks a session: every failure is reported and the hook exits 0.

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# ── 1. Rules ───────────────────────────────────────────────────────────────────

if [ -f "$PLUGIN_ROOT/rules/rules.md" ]; then
  echo "<rubstack-rules>"
  cat "$PLUGIN_ROOT/rules/rules.md"
  echo "</rubstack-rules>"
  echo ""
fi

cd "$PROJECT_DIR" 2>/dev/null || exit 0

# ── 2. Doctier with a dedicated key (cloud sessions) ───────────────────────────
#
# RUBSTACK_DOCTIER_KEY holds a passphrase-less ed25519 private key, base64
# encoded, that was granted with `doctier grant` in the repos it may read.
# Set it on your personal cloud environment only. Locally it is normally unset
# and doctier uses your own SSH key.

setup_doctier() {
  [ -n "${RUBSTACK_DOCTIER_KEY:-}" ] || return 0
  [ -f .doctier.yml ] || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local key_file="$HOME/.ssh/rubstack_doctier"
  if [ ! -s "$key_file" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    if ! (umask 077 && printf '%s' "$RUBSTACK_DOCTIER_KEY" | base64 -d > "$key_file" 2>/dev/null) \
       || ! grep -q 'PRIVATE KEY' "$key_file"; then
      rm -f "$key_file"
      echo "rubstack: RUBSTACK_DOCTIER_KEY is not a base64-encoded private key; .rubstack/ stays encrypted."
      return 0
    fi
  fi
  export DOCTIER_SSH_KEY="$key_file"
  # Later Bash commands (and the git filter they trigger) need the same key.
  if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qs 'DOCTIER_SSH_KEY' "$CLAUDE_ENV_FILE"; then
    echo "export DOCTIER_SSH_KEY=\"$key_file\"" >> "$CLAUDE_ENV_FILE"
  fi

  if ! command -v doctier >/dev/null 2>&1; then
    # Prefer installing doctier in the environment's setup script (cached with
    # the container); this is the fallback when that wasn't done.
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL --max-time 30 https://raw.githubusercontent.com/RubenGlez/doctier/main/install.sh \
         | DOCTIER_INSTALL="$HOME/.local/bin" sh >/dev/null 2>&1; then
      export PATH="$HOME/.local/bin:$PATH"
    fi
    if ! command -v doctier >/dev/null 2>&1; then
      echo "rubstack: could not install doctier; .rubstack/ stays encrypted. Add the doctier install to the environment's setup script."
      return 0
    fi
  fi

  # Filter config and hooks live in .git/config, so a fresh clone needs init.
  git config --get-regexp "^filter\.doctier\." >/dev/null 2>&1 || doctier init >/dev/null 2>&1

  local sample
  sample=$(git ls-files .rubstack 2>/dev/null | head -1)
  if [ -n "$sample" ] && head -c 40 "$sample" 2>/dev/null | grep -q 'AGE ENCRYPTED'; then
    if doctier unlock >/dev/null 2>&1; then
      echo "rubstack: decrypted .rubstack/ with the cloud key."
    else
      echo "rubstack: doctier unlock failed — is the key granted in this repo? (doctier grant \"<rubstack_cloud.pub>\")"
    fi
  fi
}

setup_doctier

# ── 3. Status ──────────────────────────────────────────────────────────────────

bash "$PLUGIN_ROOT/scripts/hooks/rubstack-status.sh"
exit 0
