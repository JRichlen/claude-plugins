#!/usr/bin/env bash
# Inject an unfilled scaffold placeholder token into shipped prose.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
skill="$root/plugins/sample-guard/skills/sample-guard/SKILL.md"
printf '\n%s\n' 'TODO: {{fill_this_in}}' >> "$skill"
