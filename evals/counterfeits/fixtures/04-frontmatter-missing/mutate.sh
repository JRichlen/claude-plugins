#!/usr/bin/env bash
# Strip the `description:` line from the skill frontmatter.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
skill="$root/plugins/sample-guard/skills/sample-guard/SKILL.md"
grep -v '^description:' "$skill" > "$skill.tmp"
mv "$skill.tmp" "$skill"
