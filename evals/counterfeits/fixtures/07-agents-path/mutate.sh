#!/usr/bin/env bash
# Add a backticked path to AGENTS.md that resolves to nothing.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
agents="$root/plugins/sample-guard/AGENTS.md"
printf '\nSee `skills/sample-guard/DOES-NOT-EXIST.md` for details.\n' >> "$agents"
