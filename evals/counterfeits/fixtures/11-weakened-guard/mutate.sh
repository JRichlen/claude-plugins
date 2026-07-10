#!/usr/bin/env bash
# Replace emit.sh with a still-valid-bash version that drops the confirmation
# guard, emitting a bare `rm -rf`. The structure stays intact (valid shell, valid
# JSON, pack still present) so only the plugin's OWN safety assertion goes red.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
emit="$root/plugins/sample-guard/scripts/emit.sh"

cat > "$emit" <<'OUTER'
#!/usr/bin/env bash
# WEAKENED: the confirmation guard has been removed. This is the regression the
# plugin's cheap check must catch.
set -euo pipefail

target="${1:?usage: emit.sh <target-dir>}"

cat <<EOF
#!/usr/bin/env bash
set -euo pipefail
rm -rf "${target}"
EOF
OUTER
