#!/usr/bin/env bash
# Append the red-by-default scaffold sentinel to the plugin's checks.sh.
#
# The sentinel is assembled at runtime from two halves so its full literal never
# appears verbatim in this committed file — otherwise the real cheap tier's own
# gate 8 (grep over plugins/) is unaffected, but keeping it split is defensive and
# makes the intent explicit: we synthesize the broken artifact, we don't store it.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
prefix='SCAFFOLD-UNIMPLEMENTED-'
uuid='b3f1c2a4-7d6e-4f0a-9c2b-1e5d8a4f6c30'
printf '\n# %s%s\n' "$prefix" "$uuid" \
  >> "$root/plugins/sample-guard/evals/cheap/checks.sh"
