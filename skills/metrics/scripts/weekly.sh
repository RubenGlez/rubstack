#!/usr/bin/env bash
# Weekly metrics collection, the same locally and in a cloud Routine.
#
# State (config, recommendations, snapshots) lives in the database of a private
# Artifact titled "rubstack metrics", never in a git repo: rubstack is public
# and the state names private repos, traffic and Search Console data. Bash
# cannot reach that database, so the run is split:
#
#   1. Claude pulls the state into $RUBSTACK_METRICS_HOME with ArtifactData
#      (`list` with out_dir), giving state/config.json, state/recommendations.json
#      and snapshots/*.json.
#   2. This script runs the collector against that mirror and prints the path
#      of the new snapshot on its last line.
#   3. Claude pushes that file back with ArtifactData (`set`, collection
#      "snapshots", doc_id = the date, file_path = the printed path).
#
# Without an authenticated gh (cloud), GitHub sources are recorded as gaps;
# a local run fills them in, traffic included.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="${RUBSTACK_METRICS_HOME:-$HOME/.rubstack/metrics}"

if [ ! -f "$STATE/state/config.json" ]; then
  echo "metrics: no $STATE/state/config.json; pull the state artifact first (see the metrics skill)" >&2
  exit 1
fi

RUBSTACK_METRICS_HOME="$STATE" python3 "$HERE/collect.py"

snapshot="$STATE/snapshots/$(date +%F).json"  # collect.py names it by local date
[ -f "$snapshot" ] || { echo "metrics: collector wrote no snapshot at $snapshot" >&2; exit 1; }
echo "$snapshot"
