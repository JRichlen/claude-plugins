#!/usr/bin/env bash
#
# Portability linter — a plugin's prose may lean on Claude-Code-only machinery
# (hooks, subagents, the Workflow tool and its parallel()/pipeline() primitives),
# but if it does, it must SAY SO: somewhere in the plugin there has to be a caveat
# telling a reader on another harness that the *discipline* ports even though the
# named primitive doesn't. Undeclared CC-only prose is the regression this catches
# — a skill that silently assumes Claude Code and breaks anyone porting it.
#
# Usage:   portability-lint.sh <plugin-dir>
# Exit 0 = clean (no CC-only tokens, or they're covered by a caveat).
# Exit 1 = a prose file leans on a CC-only primitive with no portability caveat.
#
# This lives with the eval harness, not inside any plugin, so the generic core
# never depends on one plugin. It's invoked per-plugin from evals/cheap/run.sh.
set -uo pipefail

dir="${1:?usage: portability-lint.sh <plugin-dir>}"
[ -d "$dir" ] || { echo "portability-lint: no such dir: $dir" >&2; exit 2; }

# Claude-Code-specific primitives. A plugin naming any of these in prose is fine
# ONLY if it also carries a caveat (below). Kept as extended-regex alternatives.
CC_ONLY='\bhooks?\b|\bsub-?agents?\b|Workflow tool|PreToolUse|PostToolUse|parallel\(|pipeline\('

# A caveat that acknowledges the primitive is CC-specific but the pattern ports.
CAVEAT='harness-agnostic|harness-portable|PORTABILITY:|ports? to (any|other|another) harness|re-implement it with'

# Only prose steers a reader across harnesses; skip code/templates/json.
prose=()
while IFS= read -r f; do prose+=("$f"); done < <(find "$dir" -type f -name '*.md' | sort)
[ "${#prose[@]}" -eq 0 ] && exit 0

hits=()
for f in "${prose[@]}"; do
  if grep -nEq "$CC_ONLY" "$f"; then hits+=("$f"); fi
done

# No CC-only prose anywhere → nothing to caveat, clean.
[ "${#hits[@]}" -eq 0 ] && exit 0

# CC-only prose exists → the plugin must carry a caveat somewhere in its prose.
if grep -rEq "$CAVEAT" "${prose[@]}"; then
  exit 0
fi

echo "portability-lint: $dir references Claude-Code-only primitives without a portability caveat" >&2
for f in "${hits[@]}"; do
  echo "  - $f uses: $(grep -oE "$CC_ONLY" "$f" | sort -u | paste -sd' ' -)" >&2
done
echo "  Add a caveat (e.g. 'the discipline is harness-agnostic; re-implement it with your harness's fan-out primitive')." >&2
exit 1
