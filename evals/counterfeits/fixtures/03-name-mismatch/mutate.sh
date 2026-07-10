#!/usr/bin/env bash
# Rename the plugin in its manifest so it no longer matches the marketplace entry.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
manifest="$root/plugins/sample-guard/.claude-plugin/plugin.json"
python3 - "$manifest" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["name"] = "sample-guard-RENAMED"
json.dump(d, open(p, "w"), indent=2)
PY
