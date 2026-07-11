#!/usr/bin/env bash
# Winner #15 — push the frozen required checks into GitHub branch protection.
#
# This is the ONE privileged, networked half of the branch-protection lock, so it
# is a script the USER runs, never something an agent or an eval invokes. By
# default it only PRINTS the change it would make (the required check contexts and
# the target branch). It mutates protection settings solely when you pass --apply,
# and even then it refuses to run unless `gh` is authenticated. Nothing here reads
# a secret or writes one to output.
#
# Usage:
#   ci/apply-branch-protection.sh                      # dry run — print the plan
#   ci/apply-branch-protection.sh --apply [--branch main] [--repo owner/name]
#
# The required check contexts come from ci/required-checks.json, the same frozen
# source of truth check_branch_protection.py verifies against the workflow — so
# what CI emits, what protection requires, and what this script applies stay one
# list.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPEC="$REPO_ROOT/ci/required-checks.json"

apply=false
branch="main"
repo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=true ;;
    --branch) branch="$2"; shift ;;
    --repo) repo="$2"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

# Read the frozen check contexts (one per line) with python3 — no jq dependency.
# Plain while-read loop rather than mapfile so this runs on macOS bash 3.2 too.
CHECKS=()
while IFS= read -r line; do
  [ -n "$line" ] && CHECKS+=("$line")
done < <(python3 -c '
import json, sys
with open(sys.argv[1]) as fh:
    for c in json.load(fh)["required_checks"]:
        print(c)
' "$SPEC")

echo "Target branch : $branch"
echo "Required checks (${#CHECKS[@]}):"
for c in "${CHECKS[@]}"; do echo "  - $c"; done

if ! $apply; then
  echo
  echo "DRY RUN — nothing changed. Re-run with --apply to write these to branch protection."
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found; install it or set protection manually." >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated (run 'gh auth login')." >&2
  exit 1
fi

repo_flag=()
[ -n "$repo" ] && repo_flag=(--repo "$repo")

# Build the required_status_checks.contexts array as JSON from the frozen list.
contexts_json="$(printf '%s\n' "${CHECKS[@]}" | python3 -c '
import json, sys
print(json.dumps([l.rstrip("\n") for l in sys.stdin if l.strip()]))
')"

echo
echo "Applying branch protection to '$branch'…"
# ${repo_flag[@]+...} guards the empty-array expansion: bash 3.2 under `set -u`
# treats a bare "${repo_flag[@]}" as unbound when no --repo was passed.
gh api --method PUT ${repo_flag[@]+"${repo_flag[@]}"} \
  "repos/{owner}/{repo}/branches/$branch/protection" \
  --input - <<JSON
{
  "required_status_checks": { "strict": true, "contexts": $contexts_json },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null
}
JSON
echo "Done. Verify with: python3 ci/check_branch_protection.py --repo ."
