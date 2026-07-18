#!/usr/bin/env bash
set -euo pipefail
root="${1:?usage: mutate.sh <synthetic-root>}"
sed -i 's/"counterfeit tier"/"counterfeit tier RENAMED"/' "$root/ci/required-checks.json"
