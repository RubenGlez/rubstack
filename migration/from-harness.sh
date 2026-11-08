#!/usr/bin/env bash
# One-time move of a machine from the harness plugin to rubstack.
# Run it on your own machine (not in a cloud session). Every step checks
# whether it is already done, so it is safe to re-run.
#
#   1. Metrics state: ~/.harness/metrics → metrics-data branch at ~/.rubstack/metrics, pushed.
#   2. Uninstall harness (plugin, rules block in ~/.claude/CLAUDE.md, status line,
#      Codex/OpenCode links, metrics launchd job) with harness's own uninstall.sh.
#   3. Cloud key for public repos: creates ~/.ssh/rubstack_cloud if missing and
#      prints the value to paste as RUBSTACK_DOCTIER_KEY in the cloud environment.
#
# Usage: bash migration/from-harness.sh [--harness-dir PATH] [--no-cloud-key]
set -euo pipefail

REMOTE="https://github.com/RubenGlez/rubstack"
OLD_METRICS="$HOME/.harness/metrics"
NEW_METRICS="${RUBSTACK_METRICS_HOME:-$HOME/.rubstack/metrics}"
HARNESS_DIR="$(cat "$HOME/.harness_dir" 2>/dev/null || true)"
CLOUD_KEY=1

while [ $# -gt 0 ]; do
  case "$1" in
    --harness-dir) HARNESS_DIR="$2"; shift 2 ;;
    --no-cloud-key) CLOUD_KEY=0; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

step() { printf '\n== %s\n' "$1"; }

# ── 1. Metrics state ───────────────────────────────────────────────────────────

step "1. Metrics state"
if [ ! -d "$NEW_METRICS/.git" ]; then
  git clone -q --single-branch --branch metrics-data "$REMOTE" "$NEW_METRICS"
  echo "cloned metrics-data → $NEW_METRICS"
fi
if [ -f "$NEW_METRICS/config.json" ]; then
  echo "already on metrics-data: config.json present, nothing to import"
elif [ -f "$OLD_METRICS/config.json" ]; then
  for f in config.json recommendations.json; do
    [ -f "$OLD_METRICS/$f" ] && cp "$OLD_METRICS/$f" "$NEW_METRICS/"
  done
  [ -d "$OLD_METRICS/snapshots" ] && cp -R "$OLD_METRICS/snapshots" "$NEW_METRICS/"
  git -C "$NEW_METRICS" add -A
  git -C "$NEW_METRICS" commit -q -m "metrics: import state from harness"
  git -C "$NEW_METRICS" push -q origin metrics-data
  echo "imported $(find "$NEW_METRICS/snapshots" -name '*.json' 2>/dev/null | wc -l | tr -d ' ') snapshots and pushed"
else
  echo "no harness metrics state at $OLD_METRICS; run /metrics once to create it"
fi

# ── 2. Uninstall harness ───────────────────────────────────────────────────────

step "2. Uninstall harness"
if [ -n "$HARNESS_DIR" ] && [ -f "$HARNESS_DIR/uninstall.sh" ]; then
  bash "$HARNESS_DIR/uninstall.sh"
else
  echo "harness not installed here (no ~/.harness_dir); skipping"
fi

# ── 3. Cloud key ───────────────────────────────────────────────────────────────

step "3. Cloud key for public repos"
if [ "$CLOUD_KEY" = 1 ]; then
  if [ ! -f "$HOME/.ssh/rubstack_cloud" ]; then
    command -v ssh-keygen >/dev/null || { echo "ssh-keygen not found; install OpenSSH and re-run" >&2; exit 1; }
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -q -t ed25519 -N "" -f "$HOME/.ssh/rubstack_cloud" -C rubstack-cloud
    echo "created ~/.ssh/rubstack_cloud"
  else
    echo "~/.ssh/rubstack_cloud already exists"
  fi
  echo "Public key (grant it in each public repo; /migrate-docs does this for you):"
  echo "  $(cat "$HOME/.ssh/rubstack_cloud.pub")"
  echo "Value for RUBSTACK_DOCTIER_KEY (paste it in the cloud environment's settings, never in a chat):"
  echo "  $(base64 < "$HOME/.ssh/rubstack_cloud" | tr -d '\n')"
else
  echo "skipped (--no-cloud-key)"
fi

step "Done"
echo "Next: in each project, open Claude Code and run /migrate-docs (or fleet mode from your workspace)."
