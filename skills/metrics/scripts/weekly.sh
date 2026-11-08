#!/usr/bin/env bash
# Weekly metrics collection, the same locally and in a cloud Routine.
#
# State (config.json, snapshots/, recommendations.json) lives on the
# metrics-data branch of the rubstack repo, checked out at
# $RUBSTACK_METRICS_HOME. This script brings that checkout up to date, runs the
# collector, and commits and pushes the new snapshot.
#
# Without an authenticated gh (cloud), GitHub sources are recorded as gaps;
# a local run fills them in, traffic included.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${RUBSTACK_METRICS_HOME:-$HOME/.rubstack/metrics}"
REMOTE="${RUBSTACK_METRICS_REMOTE:-https://github.com/RubenGlez/rubstack}"
BRANCH="metrics-data"

if [ -d "$STATE/.git" ]; then
  git -C "$STATE" pull -q --ff-only origin "$BRANCH"
else
  git clone -q --single-branch --branch "$BRANCH" "$REMOTE" "$STATE"
fi

if [ ! -f "$STATE/config.json" ]; then
  echo "metrics: no config.json on $BRANCH; seed it from a local run first (see the metrics skill)" >&2
  exit 1
fi

RUBSTACK_METRICS_HOME="$STATE" python3 "$HERE/collect.py"

git -C "$STATE" add -A snapshots
if git -C "$STATE" diff --cached --quiet; then
  echo "metrics: nothing new to commit"
  exit 0
fi
git -C "$STATE" -c user.name="${GIT_AUTHOR_NAME:-rubstack metrics}" -c user.email="${GIT_AUTHOR_EMAIL:-metrics@rubstack.invalid}" \
  commit -q -m "metrics: snapshot $(date -u +%F)"
git -C "$STATE" push -q origin "$BRANCH"
echo "metrics: pushed snapshot to $BRANCH"
