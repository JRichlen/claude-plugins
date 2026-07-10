#!/usr/bin/env bash
#
# sample-guard — plugin-specific cheap checks.
#
# SOURCED by the shared runner (evals/cheap/run.sh), not run on its own: it inherits
# that runner's helpers (ok/bad/group), its `set -uo pipefail`, and a working
# directory of the marketplace root. PLUGIN_NAME / PLUGIN_DIR are exported for us.
#
# These prove the plugin's single safety invariant: the emitted script never deletes
# without a confirmation guard. When the counterfeit corpus weakens emit.sh, THIS is
# the check that must go red — proving a sourced safety pack actually bites.

group "sample-guard — guarded destructive emit"
EMIT="$PLUGIN_DIR/scripts/emit.sh"

# Refuses with no target (fail-closed on missing input).
if bash "$EMIT" >/dev/null 2>&1; then
  bad "emit.sh should exit non-zero with no target"
else
  ok "emit.sh refuses empty invocation"
fi

# The emitted script guards its rm -rf behind a confirmation check.
out="$(bash "$EMIT" scratch 2>/dev/null)"
if grep -q 'Confirmation did not match; aborting' <<<"$out"; then
  ok "emitted script guards deletion behind a confirmation check"
else
  bad "emit.sh is MISSING its confirmation guard before rm -rf"
fi
