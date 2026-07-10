#!/usr/bin/env bash
#
# sample-guard — emit a destructive cleanup command wrapped in a confirmation guard.
#
# The invariant this tiny plugin defends: the destructive `rm -rf` line is ALWAYS
# preceded by a guard that forces the operator to confirm the exact target before
# anything is deleted. It mirrors the graveyard discipline (never act destructively
# without a verified precondition) in a self-contained, dependency-free form so the
# counterfeit corpus has a real safety invariant to weaken.
set -euo pipefail

target="${1:?usage: emit.sh <target-dir>}"

# Emit (to stdout) a script the operator reviews and runs. The confirmation guard
# is the whole point: a bare `rm -rf` with no guard is exactly the regression the
# plugin's cheap check exists to catch.
cat <<EOF
#!/usr/bin/env bash
# Review this script before running it. It deletes a directory.
set -euo pipefail
read -r -p "Delete ${target}? Retype the directory name to confirm: " reply
if [ "\$reply" != "${target}" ]; then
  echo "Confirmation did not match; aborting." >&2
  exit 1
fi
rm -rf "${target}"
EOF
