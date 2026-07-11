#!/usr/bin/env bash
# evals/paid/discover-paid-packs.sh — fail-closed discovery of paid eval packs.
#
# The cheap and counterfeit tiers are free and run on every change, so they
# require EVERY registered plugin to ship a pack (see evals/cheap/run.sh §10).
# The paid tiers cost real API spend, so the asymmetry flips: not every plugin
# has a behavioral (promptfoo) or deep (pier) pack, and a plugin that ships
# none for a tier simply contributes no CI legs. But a plugin that *declares* a
# pack — the tier directory exists — with a missing or broken required entry is
# a hard FAILURE. A half-built paid pack must never silently drop out of
# coverage; that would let a real regression ship because "the pack ran" when it
# never actually did. "Declared but broken ⇒ fail; absent ⇒ contribute nothing"
# is the whole contract this script encodes, and it is the single source of
# truth the workflow's paid matrices are built from (via fromJSON).
#
# Usage:
#   discover-paid-packs.sh promptfoo    # JSON array of plugins w/ valid promptfoo packs
#   discover-paid-packs.sh pier         # JSON array of plugins w/ valid pier packs
#   discover-paid-packs.sh --self-test  # run internal fixtures; non-zero on failure
#
# The JSON array on stdout drives a GitHub Actions matrix through fromJSON(). An
# empty pool prints [] so the required aggregation gate can go green with zero
# legs (a repo state with no paid packs is valid, not broken). Any problem emits
# a ::error:: annotation and exits non-zero, which fails the discovery job — and
# the required aggregation gate that needs it then reports red.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# evals/paid/../.. = repo root. Plugin sources in marketplace.json are relative
# to this root (e.g. ./plugins/graveyard), so every pack path resolves from here.
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# The required entry each tier's pack MUST provide. The pack's presence is the
# tier directory; the required entry is what proves the pack is real, not a
# leftover empty folder. Validity is tier-specific (see validate_entry).
required_entry() {
  case "$1" in
    promptfoo) printf '%s\n' "promptfooconfig.yaml" ;;
    pier)      printf '%s\n' "run.sh" ;;
    *)         return 1 ;;
  esac
}

# Prove a declared pack's required entry is actually usable. promptfoo needs a
# non-empty config for `promptfoo eval` to have anything to run; pier's run.sh
# must at least parse (`bash -n`) or CI would fail deep inside a paid job that
# should never have been dispatched. Emits ::error:: + returns 1 on any problem.
validate_entry() {
  local tier="$1" name="$2" target="$3"
  if [ ! -f "$target" ]; then
    echo "::error::plugin '$name' declares a $tier pack but is missing required entry ($target)" >&2
    return 1
  fi
  case "$tier" in
    promptfoo)
      if [ ! -s "$target" ]; then
        echo "::error::plugin '$name' $tier pack entry is empty ($target)" >&2
        return 1
      fi
      ;;
    pier)
      if ! bash -n "$target" 2>/dev/null; then
        echo "::error::plugin '$name' $tier pack entry fails 'bash -n' ($target)" >&2
        return 1
      fi
      ;;
  esac
  return 0
}

# Enumerate marketplace-registered plugins as "name<TAB>source" lines. Only the
# marketplace is authoritative: a stray plugins/<x>/evals/promptfoo/ that isn't
# registered contributes nothing, matching how the cheap tier scopes discovery.
list_plugins() {
  python3 - "$1" <<'PY'
import json, os, sys
root = sys.argv[1]
mkt = json.load(open(os.path.join(root, ".claude-plugin", "marketplace.json")))
for p in mkt.get("plugins", []):
    src = (p.get("source", "") or "").lstrip("./").rstrip("/")
    print(f"{p.get('name','')}\t{src}")
PY
}

# json.dumps of the argv list — compact, fromJSON-ready. No args ⇒ [].
emit_json_array() {
  python3 - "$@" <<'PY'
import json, sys
print(json.dumps(sys.argv[1:]))
PY
}

# discover <tier> <root> -> prints JSON array of plugins with a valid pack, or
# emits ::error:: and returns non-zero on the first declared-but-broken pack.
discover() {
  local tier="$1" root="$2"
  local entry
  if ! entry="$(required_entry "$tier")"; then
    echo "::error::unknown paid tier '$tier' (expected 'promptfoo' or 'pier')" >&2
    return 2
  fi

  local plugins=()
  local line name src packdir
  while IFS= read -r line; do
    name="${line%%$'\t'*}"
    src="${line#*$'\t'}"
    packdir="$root/$src/evals/$tier"
    # Absent ⇒ contribute nothing (this plugin has no pack for this tier).
    [ -d "$packdir" ] || continue
    # Declared ⇒ must be valid, or fail closed for the whole discovery.
    validate_entry "$tier" "$name" "$packdir/$entry" || return 1
    plugins+=("$name")
  done < <(list_plugins "$root")

  if [ "${#plugins[@]}" -eq 0 ]; then
    emit_json_array
  else
    emit_json_array "${plugins[@]}"
  fi
}

# --- self-test ---------------------------------------------------------------
# Proves the two behaviors that matter: (1) the real repo resolves graveyard for
# both tiers, and (2) fail-closed actually fires — a declared-but-broken pack is
# rejected while an absent pack is silently skipped. Builds a throwaway
# marketplace root for the fail-closed cases so nothing broken touches the repo.
self_test() {
  local failures=0
  check() { # check <label> <expected> <actual>
    if [ "$2" = "$3" ]; then
      echo "PASS: $1"
    else
      echo "FAIL: $1 (want [$2], got [$3])"
      failures=$((failures + 1))
    fi
  }

  # 1. Real repo: graveyard ships both paid packs, the other plugins ship none.
  local got
  got="$(discover promptfoo "$REPO_ROOT")" || got="<error>"
  check 'real repo promptfoo' '["graveyard"]' "$got"
  got="$(discover pier "$REPO_ROOT")" || got="<error>"
  check 'real repo pier' '["graveyard"]' "$got"

  # 2. Synthetic root exercising every branch of the contract. Cleaned up at the
  # single return below — a RETURN trap would be global and re-fire (with tmp out
  # of scope, tripping set -u) when the caller returns.
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.claude-plugin"
  cat > "$tmp/.claude-plugin/marketplace.json" <<'JSON'
{"plugins":[
  {"name":"good","source":"./plugins/good"},
  {"name":"nopack","source":"./plugins/nopack"},
  {"name":"broken","source":"./plugins/broken"}
]}
JSON
  # good: valid promptfoo pack. nopack: no evals dir. broken: declares a
  # promptfoo pack but the required config is absent.
  mkdir -p "$tmp/plugins/good/evals/promptfoo"
  printf 'description: x\n' > "$tmp/plugins/good/evals/promptfoo/promptfooconfig.yaml"
  mkdir -p "$tmp/plugins/nopack"
  mkdir -p "$tmp/plugins/broken/evals/promptfoo"

  # 2a. broken present ⇒ fail closed (non-zero), good/nopack notwithstanding.
  if discover promptfoo "$tmp" >/dev/null 2>&1; then
    echo "FAIL: declared-but-broken pack did not fail closed"
    failures=$((failures + 1))
  else
    echo "PASS: declared-but-broken pack fails closed"
  fi

  # 2b. Remove the broken declaration ⇒ only good contributes; nopack skipped.
  rm -rf "$tmp/plugins/broken/evals"
  got="$(discover promptfoo "$tmp")" || got="<error>"
  check 'absent pack contributes nothing' '["good"]' "$got"

  # 2c. No plugin ships a pier pack ⇒ empty pool prints [] (green with 0 legs).
  got="$(discover pier "$tmp")" || got="<error>"
  check 'empty pool prints []' '[]' "$got"

  rm -rf "$tmp"

  if [ "$failures" -eq 0 ]; then
    echo "discover-paid-packs self-test: all checks passed"
    return 0
  fi
  echo "discover-paid-packs self-test: $failures check(s) failed" >&2
  return 1
}

main() {
  local arg="${1:-}"
  case "$arg" in
    --self-test)     self_test ;;
    promptfoo|pier)  discover "$arg" "$REPO_ROOT" ;;
    ""|-h|--help)
      echo "usage: discover-paid-packs.sh <promptfoo|pier|--self-test>" >&2
      return 2 ;;
    *)
      echo "::error::unknown argument '$arg' (expected promptfoo, pier, or --self-test)" >&2
      return 2 ;;
  esac
}

main "$@"
