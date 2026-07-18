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
# Matched case-insensitively (below) so "On any other harness…" counts.
CAVEAT='harness-agnostic|harness-portable|PORTABILITY:|ports? to (any|other|another) harness|on (any|other|another) harness|re-implement it with|not a (hard )?dependency|convenience, not a dependency'

# Only prose steers a reader across harnesses; skip code/templates/json.
prose=()
while IFS= read -r f; do prose+=("$f"); done < <(find "$dir" -type f -name '*.md' | sort)
[ "${#prose[@]}" -eq 0 ] && exit 0

# CO-LOCATED: each prose file that leans on a CC-only primitive must carry the
# caveat IN THAT FILE. A caveat buried in an unrelated doc doesn't help a reader
# of the file that actually uses the primitive, and lets every other file in the
# plugin reference CC-only machinery uncaveated once one file mentions it.
violations=()
for f in "${prose[@]}"; do
  grep -Eq "$CC_ONLY" "$f" || continue     # this file doesn't use a CC-only primitive
  grep -Eiq "$CAVEAT" "$f" && continue       # ...and if it does, it carries its own caveat
  violations+=("$f")
done

[ "${#violations[@]}" -eq 0 ] && exit 0

echo "portability-lint: $dir has file(s) referencing Claude-Code-only primitives without a portability caveat co-located in the file" >&2
for f in "${violations[@]}"; do
  echo "  - $f uses: $(grep -oE "$CC_ONLY" "$f" | sort -u | paste -sd' ' -) (no caveat in this file)" >&2
done
echo "  Add a caveat in EACH such file (e.g. 'the discipline is harness-agnostic; re-implement it with your harness's fan-out primitive')." >&2
exit 1
