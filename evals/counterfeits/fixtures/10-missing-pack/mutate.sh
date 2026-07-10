#!/usr/bin/env bash
# Delete the plugin's cheap eval pack — a registered plugin must not ship without one.
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
rm -f "$root/plugins/sample-guard/evals/cheap/checks.sh"
