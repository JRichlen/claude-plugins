#!/usr/bin/env bash
#
# Run the graveyard deep tier with pier.
#
# Stages a FRESH copy of the live plugin scripts into each task's
# environment/skill/ (so the sandbox always tests current source, never a stale
# committed duplicate), then invokes pier for every agent in agents/agents.yaml.
#
# Prereqs:
#   - pier installed:  uv tool install datacurve-pier   (or pip install datacurve-pier)
#   - Docker running (default env) or Modal configured (--env modal)
#   - a .env file at evals/pier/.env with the provider keys the agents need
#
# Usage:
#   evals/pier/run.sh                       # all agents, docker
#   evals/pier/run.sh --agent claude-code   # one agent
#   evals/pier/run.sh --env modal           # run on Modal instead of Docker
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SKILL_SRC="$REPO_ROOT/plugins/graveyard/skills/graveyard/scripts"

# 1. Stage live skill scripts into every task's build context.
for task in "$HERE"/tasks/*/; do
  dest="$task/environment/skill"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$SKILL_SRC"/*.sh "$dest"/
done

# 2. Hand off to pier. Extra args (‑‑agent, ‑‑env, ‑‑n-tasks, ...) pass through.
#    Confirm the exact flags for your pier version with `pier run --help`.
ENV_FILE_ARG=()
[ -f "$HERE/.env" ] && ENV_FILE_ARG=(--env-file "$HERE/.env")

exec pier run \
  -p "$HERE/tasks/graveyard-guarded-delete" \
  --agents "$HERE/agents/agents.yaml" \
  --env docker \
  "${ENV_FILE_ARG[@]}" \
  "$@"
