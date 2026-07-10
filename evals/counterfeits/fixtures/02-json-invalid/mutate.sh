#!/usr/bin/env bash
# Corrupt the plugin manifest into invalid JSON.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
printf '%s\n' '{ "name": "sample-guard", not valid json' \
  > "$root/plugins/sample-guard/.claude-plugin/plugin.json"
