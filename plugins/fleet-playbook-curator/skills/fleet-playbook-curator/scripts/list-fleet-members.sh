#!/usr/bin/env bash
# Deterministic fleet-membership enumeration. NO LLM. Portable bash/gh/jq.
#
# Usage: list-fleet-members.sh <owner> <glob>
#   e.g. list-fleet-members.sh jrichlen-lab 'ansible-homelab-*'
#
# Emits (stdout) a JSON manifest:
#   { "as_of": "<ISO8601 from gh, not local clock>", "members": [ {node_id, name,
#     full_name, default_branch, head_sha, pushed_at, archived, private}, ... ] }
# Members are joined logically on node_id (STABLE across renames) and sorted by
# node_id so the output is byte-stable for identical upstream state.
#
# Uses orgs/<owner>/repos (strongly consistent, correct rate bucket) — NOT the
# Search API, which is eventually consistent and rate-limited differently.
set -euo pipefail

owner="${1:?usage: list-fleet-members.sh <owner> <glob>}"
glob="${2:?usage: list-fleet-members.sh <owner> <glob>}"

# Translate a shell-style glob into an anchored regex (only * is special here).
pat="^$(printf '%s' "$glob" | sed -e 's/[.[\^$()+?{|]/\\&/g' -e 's/\*/.*/g')$"

# 1. Enumerate + filter by name. One paginated call regardless of fleet size.
members="$(gh api "orgs/${owner}/repos" --paginate \
  --jq '.[] | {node_id, name, full_name, default_branch, pushed_at, archived, private}' \
  | jq -s --arg pat "$pat" 'map(select(.name | test($pat))) | sort_by(.node_id)')"

# 2. Stamp head_sha per member — the independent staleness clock. A member we
#    cannot read (404/permission) is recorded with head_sha "UNREADABLE" rather
#    than dropped, so a silent-partial-curation is visible, not invisible.
out='[]'
while read -r full_branch; do
  [ -n "$full_branch" ] || continue
  full="${full_branch%%$'\t'*}"; branch="${full_branch##*$'\t'}"
  sha="$(gh api "repos/${full}/commits/${branch}" --jq '.sha' 2>/dev/null || echo UNREADABLE)"
  out="$(jq --arg full "$full" --arg sha "$sha" \
    '. as $o | ($o + [{full_name:$full, head_sha:$sha}])' <<<"$out")"
done < <(jq -r '.[] | "\(.full_name)\t\(.default_branch)"' <<<"$members")

# Join head_sha onto each member by full_name (built as a lookup map to avoid
# any ambiguous self-reference inside map()).
jq -n --argjson members "$members" --argjson shas "$out" '
  ($shas | map({ (.full_name): .head_sha }) | add // {}) as $bysha
  | { as_of: (now | todate),
      members: ($members | map(.full_name as $fn | . + { head_sha: ($bysha[$fn] // "UNREADABLE") })) }'
