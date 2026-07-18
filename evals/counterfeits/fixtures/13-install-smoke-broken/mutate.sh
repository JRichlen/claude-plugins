#!/usr/bin/env bash
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
python3 - "$root" <<'PY'
import json, sys, glob
root = sys.argv[1]
p = glob.glob(f"{root}/plugins/*/.claude-plugin/plugin.json")[0]
d = json.load(open(p)); d["agents"] = "./agents/"   # declared dir does not exist
json.dump(d, open(p, "w"), indent=2)
PY
