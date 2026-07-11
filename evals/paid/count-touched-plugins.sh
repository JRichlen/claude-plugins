#!/usr/bin/env bash
# evals/paid/count-touched-plugins.sh — advisory multi-plugin paid-surface gate.
#
# The paid tiers (behavioral/promptfoo, deep/pier) bill real API spend per
# plugin. When a single PR changes the paid surface of MORE than one plugin, a
# red paid leg is ambiguous — which plugin regressed? — and a rerun re-bills
# every touched plugin. So this gate nudges authors toward one-plugin-per-PR.
#
# It is DELIBERATELY advisory: it always exits 0 and, on a multi-plugin touch,
# emits a ::warning:: annotation. It is NOT a required check and is never frozen
# in ci/required-checks.json — a required check that reports red on a legitimate
# multi-plugin change would hard-block the PR (and would have self-vetoed the very
# PR that introduced it). A warning informs without blocking.
#
# Paid surface = plugins/<name>/evals/{promptfoo,pier}/**. A change to the shared
# paid harness (evals/paid/**) can affect every paid pack, so it fans out to all
# plugins that currently ship a paid pack. Free-tier paths (evals/cheap,
# evals/counterfeits, evals/templates) and non-eval plugin files never count.
#
# Usage:
#   count-touched-plugins.sh              # reads BASE_SHA/HEAD_SHA from env (CI)
#   count-touched-plugins.sh --self-test  # run internal fixtures
#
# In CI the job passes BASE_SHA/HEAD_SHA via env (never interpolated into the
# shell body). Outside a pull_request event there is no reliable base..head, so
# the script no-ops green.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# Plugins that ship ANY paid pack (promptfoo or pier) — the fan-out universe for
# a shared-harness change. Reuses the single discovery source of truth. Discovery
# failure falls back to an empty universe rather than aborting (advisory gate).
paid_plugins() {
  { "$HERE/discover-paid-packs.sh" promptfoo 2>/dev/null || echo '[]'; \
    "$HERE/discover-paid-packs.sh" pier 2>/dev/null || echo '[]'; } \
  | python3 -c '
import json, sys
seen = set()
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        seen.update(json.loads(line))
    except Exception:
        pass
print("\n".join(sorted(seen)))'
}

# classify <paid-plugin...> : read newline-separated changed paths on stdin,
# print `plugin: <name>` for each distinct plugin whose paid surface is touched,
# then `MULTI=true|false`. Positional args are the fan-out universe used when the
# shared paid harness changes.
classify() {
  # NOTE: `python3 -c "$prog" "$@"` (program in an arg), NOT `python3 - <<HEREDOC`
  # — with `-` the program is read from stdin, which would collide with the piped
  # changed-file list and leave sys.stdin empty.
  local prog
  prog='
import re, sys
paid_universe = sys.argv[1:]
paid_surface = re.compile(r"^plugins/([^/]+)/evals/(?:promptfoo|pier)/")
touched = set()
fan_all = False
for raw in sys.stdin:
    p = raw.strip()
    if not p:
        continue
    m = paid_surface.match(p)
    if m:
        touched.add(m.group(1))
        continue
    if p.startswith("evals/paid/"):
        fan_all = True
if fan_all:
    touched.update(paid_universe)
plugins = sorted(touched)
for pl in plugins:
    print("plugin: " + pl)
print("MULTI=" + ("true" if len(plugins) > 1 else "false"))
'
  python3 -c "$prog" "$@"
}

# --- self-test ---------------------------------------------------------------
self_test() {
  local failures=0 out
  expect() { # expect <label> <want true|false> <output>
    if printf '%s\n' "$3" | grep -q "^MULTI=$2$"; then
      echo "PASS: $1"
    else
      echo "FAIL: $1 (want MULTI=$2)"
      printf '%s\n' "$3" | sed 's/^/  /'
      failures=$((failures + 1))
    fi
  }

  out="$(printf 'plugins/graveyard/evals/promptfoo/promptfooconfig.yaml\n' | classify graveyard other)"
  expect 'single plugin paid change is not multi' false "$out"

  out="$(printf 'plugins/graveyard/evals/promptfoo/x\nplugins/other/evals/pier/run.sh\n' | classify graveyard other)"
  expect 'two plugins paid change is multi' true "$out"

  out="$(printf 'evals/cheap/run.sh\nREADME.md\nplugins/graveyard/skills/graveyard/SKILL.md\n' | classify graveyard other)"
  expect 'free-only + non-paid plugin change is not multi' false "$out"

  out="$(printf 'evals/paid/discover-paid-packs.sh\n' | classify graveyard other)"
  expect 'shared paid harness fans out to all paid plugins (multi)' true "$out"

  out="$(printf 'evals/paid/discover-paid-packs.sh\n' | classify graveyard)"
  expect 'shared paid harness with one paid plugin is not multi' false "$out"

  out="$(printf '' | classify graveyard other)"
  expect 'empty diff is not multi' false "$out"

  if [ "$failures" -eq 0 ]; then
    echo "count-touched-plugins self-test: all checks passed"
    return 0
  fi
  echo "count-touched-plugins self-test: $failures check(s) failed" >&2
  return 1
}

main() {
  if [ "${1:-}" = "--self-test" ]; then
    self_test
    return $?
  fi

  # No reliable base..head outside a pull_request event ⇒ no-op green.
  if [ -z "${BASE_SHA:-}" ] || [ -z "${HEAD_SHA:-}" ]; then
    echo "no PR base/head in env (BASE_SHA/HEAD_SHA) — multi-plugin gate is a no-op here."
    return 0
  fi

  local paid out
  paid="$(paid_plugins || true)"
  # shellcheck disable=SC2086  # word-splitting $paid into one arg per plugin is intended.
  out="$(git -C "$REPO_ROOT" diff --name-only "$BASE_SHA" "$HEAD_SHA" 2>/dev/null | classify $paid || true)"
  printf '%s\n' "$out"

  if printf '%s\n' "$out" | grep -q '^MULTI=true$'; then
    echo "::warning::This PR touches the paid eval surface of more than one plugin. Paid tiers bill per plugin and a red paid leg is clearest when it maps to a single plugin — consider splitting into one PR per plugin."
  fi
  return 0
}

main "$@"
