#!/usr/bin/env bash
# Break shell syntax: leave an `if` unterminated so `bash -n` fails.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
printf '%s\n' '#!/usr/bin/env bash' 'if [ 1 -eq 1 ]; then' \
  > "$root/plugins/sample-guard/scripts/emit.sh"
