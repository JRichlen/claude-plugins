#!/usr/bin/env bash
# Add Claude-Code-only prose (a PreToolUse hook) with no portability caveat.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
skill="$root/plugins/sample-guard/skills/sample-guard/SKILL.md"
printf '\n%s\n' 'Wire the confirmation into a PreToolUse hook so it always runs.' >> "$skill"
