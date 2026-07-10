#!/usr/bin/env bash
#
# Run the graveyard deep tier with pier (datacurve-pier >= 0.3.0).
#
# Stages a FRESH copy of the live plugin scripts into each task's
# environment/skill/ (so the sandbox always tests current source, never a stale
# committed duplicate), then runs the guarded-delete task under each agent in
# the roster and asserts every agent lands on its expected reward.
#
# pier 0.3.0 takes ONE agent per `pier run` (-a/--agent is singular), so this
# script loops the roster itself instead of handing pier a roster file. The
# roster below is the single source of truth — there is no separate config file
# to drift out of sync with the CLI.
#
# Prereqs:
#   - pier installed:  uv tool install datacurve-pier   (or pip install datacurve-pier)
#   - Docker running (default env) or Modal/Daytona configured (PIER_ENV=modal)
#   - provider keys for the agents you run, in evals/pier/.env (git-ignored):
#       ANTHROPIC_API_KEY   claude-code (reaches api.anthropic.com via the agent
#                           network allowlist even though the task sandbox itself
#                           runs offline — the sandbox stays hermetic)
#       OPENAI_API_KEY      codex
#       GEMINI_API_KEY      gemini-cli
#       CURSOR_API_KEY      cursor-cli
#     oracle and nop need no keys and no network.
#
# Usage:
#   evals/pier/run.sh                                       # full roster, Docker
#   PIER_AGENTS="oracle nop" evals/pier/run.sh              # sanity floor, no keys
#   PIER_AGENTS="claude-code oracle nop" evals/pier/run.sh  # what CI runs
#   PIER_ENV=modal evals/pier/run.sh                        # Modal instead of Docker
#   evals/pier/run.sh --debug                               # extra flags pass to pier
#
# Exit status: 0 iff every agent in the roster reached its expected reward.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SKILL_SRC="$REPO_ROOT/plugins/graveyard/skills/graveyard/scripts"
TASK_DIR="$HERE/tasks/graveyard-guarded-delete"
JOBS_ROOT="$HERE/jobs"

# Which agents to run, and how. Override the set with PIER_AGENTS (space list).
# oracle runs the reference solution and MUST pass; nop does nothing and MUST
# fail — together they prove the verifier still discriminates. Real agents are
# expected to honor the guard and pass.
DEFAULT_AGENTS="claude-code codex gemini-cli cursor-cli oracle nop"
AGENTS="${PIER_AGENTS:-$DEFAULT_AGENTS}"
PIER_ENV="${PIER_ENV:-docker}"

# Per-agent model / kwargs / expected reward. bash 3.2-safe (no assoc arrays).
# Sets globals A_MODEL, A_KWARGS (array), A_EXPECT (0|1).
agent_config() {
  A_MODEL=""; A_KWARGS=(); A_EXPECT=1
  case "$1" in
    claude-code) A_MODEL="claude-opus-4-8"; A_KWARGS=(--ak reasoning_effort=high) ;;
    codex)       A_MODEL="gpt-5-codex" ;;
    gemini-cli)  A_MODEL="gemini-2.5-pro" ;;
    cursor-cli)  A_MODEL="claude-opus-4-8" ;;
    oracle)      A_EXPECT=1 ;;   # reference solution -> must PASS
    nop)         A_EXPECT=0 ;;   # does nothing        -> must FAIL
    *) echo "run.sh: unknown agent '$1'" >&2; return 1 ;;
  esac
}

# Read result.json and print the reward for its first trial, or ERR:<reason>.
# reward.txt (a bare 1/0) is surfaced by pier as rewards.reward — see
# pier.verifier: {"reward": float(reward.txt)}.
reward_of() {
  python3 - "$1" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("ERR:noresult"); raise SystemExit
trials = d.get("trial_results") or []
if not trials:
    print("ERR:notrials"); raise SystemExit
t = trials[0]
exc = t.get("exception_info")
if exc:
    print("ERR:" + str(exc.get("exception_type", "exception"))); raise SystemExit
vr = t.get("verifier_result")
if not vr or vr.get("rewards") is None:
    print("ERR:noreward"); raise SystemExit
r = vr["rewards"].get("reward")
print("ERR:noreward" if r is None else str(r))
PY
}

# 1. Stage the live skill scripts into every task build context.
for task in "$HERE"/tasks/*/; do
  dest="$task/environment/skill"
  rm -rf "$dest"
  mkdir -p "$dest"
  cp "$SKILL_SRC"/*.sh "$dest"/
done

# 2. Optional provider keys.
ENV_FILE_ARG=()
[ -f "$HERE/.env" ] && ENV_FILE_ARG=(--env-file "$HERE/.env")

# 3. Run each agent into its own job dir and record the outcome.
summary=()
overall=0
for agent in $AGENTS; do
  agent_config "$agent"
  job_dir="$JOBS_ROOT/$agent"
  rm -rf "$job_dir"   # pier refuses to reuse an existing job dir

  echo ">>> pier run: agent=$agent model=${A_MODEL:-<default>} env=$PIER_ENV"
  set +e
  # ${arr[@]+"${arr[@]}"} expands an array only when it has elements — under
  # `set -u`, macOS bash 3.2 treats a bare "${empty[@]}" as an unbound variable.
  pier run \
    -p "$TASK_DIR" \
    --agent "$agent" \
    ${A_MODEL:+-m "$A_MODEL"} \
    ${A_KWARGS[@]+"${A_KWARGS[@]}"} \
    --env "$PIER_ENV" \
    --jobs-dir "$JOBS_ROOT" \
    --job-name "$agent" \
    ${ENV_FILE_ARG[@]+"${ENV_FILE_ARG[@]}"} \
    "$@"
  run_rc=$?
  set -e

  result_json="$(ls -1 "$job_dir"/*/result.json 2>/dev/null | head -n1 || true)"
  if [ -z "$result_json" ]; then
    reward="ERR:noresult"
  else
    reward="$(reward_of "$result_json")"
  fi
  case "$reward" in
    ERR:*) verdict="ERROR ($reward)"; overall=1 ;;
    *)
      # normalize "1.0"/"0.0" -> integer for comparison
      got="$(python3 -c 'import sys;print(int(float(sys.argv[1])))' "$reward")"
      if [ "$got" -eq "$A_EXPECT" ]; then
        verdict="OK (reward=$got, expected=$A_EXPECT)"
      else
        verdict="MISMATCH (reward=$got, expected=$A_EXPECT)"; overall=1
      fi ;;
  esac
  if [ "$run_rc" -ne 0 ] && [ "${reward#ERR:}" != "$reward" ]; then
    verdict="$verdict [pier rc=$run_rc]"
  fi
  summary+=("$(printf '%-12s %s' "$agent" "$verdict")")
done

echo
echo "===== deep tier summary ====="
for line in "${summary[@]}"; do echo "$line"; done
echo "============================="
if [ "$overall" -eq 0 ]; then echo "deep tier: PASS"; else echo "deep tier: FAIL"; fi
exit "$overall"
