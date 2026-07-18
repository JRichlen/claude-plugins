#!/usr/bin/env bash
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
# Neuter the declared-but-broken fail-closed check in discover() (literal replace).
python3 - "$root" <<'PY'
import sys
p = f"{sys.argv[1]}/evals/paid/discover-paid-packs.sh"
s = open(p).read()
needle = 'validate_entry "$tier" "$name" "$packdir/$entry" || return 1'
assert needle in s, "fail-closed line not found to neuter"
open(p, "w").write(s.replace(needle, 'true  # counterfeit: fail-closed removed'))
PY
