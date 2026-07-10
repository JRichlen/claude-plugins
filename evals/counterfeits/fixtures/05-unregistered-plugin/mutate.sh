#!/usr/bin/env bash
# Add a plugin directory on disk with NO marketplace entry (unregistered).
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
mkdir -p "$root/plugins/orphan/.claude-plugin"
printf '%s\n' '{ "name": "orphan", "version": "0.0.1" }' \
  > "$root/plugins/orphan/.claude-plugin/plugin.json"
