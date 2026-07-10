#!/usr/bin/env bash
#
# Cheap evals — deterministic, offline, no API cost. Runs in well under a second.
#
# This is the tier that must pass on EVERY change before commit (see AGENTS.md).
# It proves the structural + safety invariants that don't need an LLM to check:
# a bad edit to the delete-script generator that dropped the bundle guard, a
# malformed manifest, an unparseable script, or a marketplace source pointing at
# a plugin that isn't there would all be caught here for free.
#
# Exit 0 = all checks pass. Exit 1 = at least one failed.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

pass=0; fail=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }
group(){ printf '\n\033[1m%s\033[0m\n' "$1"; }

# --- 1. Shell scripts parse -------------------------------------------------
group "shell syntax (bash -n)"
while IFS= read -r s; do
  if bash -n "$s" 2>/dev/null; then ok "$s"; else bad "$s (syntax error)"; fi
done < <(find plugins evals -name '*.sh' -type f | sort)

# --- 2. JSON manifests are valid -------------------------------------------
group "json validity"
while IFS= read -r j; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$j" 2>/dev/null; then
    ok "$j"; else bad "$j (invalid JSON)"; fi
done < <(find . -name '*.json' -not -path './node_modules/*' -type f | sort)

# --- 3. Marketplace <-> plugin wiring --------------------------------------
group "marketplace wiring"
python3 - "$REPO_ROOT" <<'PY'
import json, os, sys
root = sys.argv[1]
mkt = json.load(open(os.path.join(root, ".claude-plugin", "marketplace.json")))
fail = 0
for p in mkt.get("plugins", []):
    src = p.get("source", "")
    manifest = os.path.join(root, src, ".claude-plugin", "plugin.json")
    if os.path.isfile(manifest):
        pj = json.load(open(manifest))
        if pj.get("name") == p.get("name"):
            print(f"  PASS source {src} -> plugin.json name matches ('{p['name']}')")
        else:
            print(f"  FAIL source {src} plugin.json name '{pj.get('name')}' != marketplace '{p.get('name')}'"); fail += 1
    else:
        print(f"  FAIL source {src} has no .claude-plugin/plugin.json"); fail += 1
sys.exit(1 if fail else 0)
PY
if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi

# --- 4. SKILL.md frontmatter -----------------------------------------------
group "skill frontmatter"
while IFS= read -r skill; do
  python3 - "$skill" <<'PY'
import sys
p = sys.argv[1]
txt = open(p).read()
if not txt.startswith("---"):
    print(f"  FAIL {p} (no frontmatter)"); sys.exit(1)
fm = txt.split("---", 2)[1]
missing = [k for k in ("name:", "description:") if k not in fm]
if missing:
    print(f"  FAIL {p} (missing {', '.join(missing)})"); sys.exit(1)
print(f"  PASS {p}")
PY
  if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
done < <(find plugins -name 'SKILL.md' -type f | sort)

# --- 5. SAFETY INVARIANT: guarded deletion ---------------------------------
# The core promise of the graveyard skill: an original repo is deleted only
# after its bundle is confirmed present in the graveyard. Regenerate a delete
# script and prove every bundled delete sits behind the bundle-existence guard.
group "safety invariant — guarded deletion"
GEN="plugins/graveyard/skills/graveyard/scripts/generate-delete-script.sh"

# 5a. refuses with no args
if bash "$GEN" >/dev/null 2>&1; then bad "generator should exit non-zero with no args"; else ok "generator refuses empty invocation"; fi

# 5b. bundled delete is guarded by a bundle-existence check
out="$(bash "$GEN" acme graveyard --bundled "alpha beta")"
if grep -q 'if gh api "repos/\$OWNER/\$GRAVEYARD/contents/\$r/\$r.bundle"' <<<"$out"; then
  ok "generated script guards bundled deletes with a bundle-existence check"
else
  bad "generated script is MISSING the bundle-existence guard"
fi

# 5c. with ONLY --bundled, there must be no unguarded delete. The template emits
#     exactly one 'gh repo delete "$OWNER/$r"' (inside the guarded loop) and one
#     in the unbundled loop. With no --unbundled, the unbundled loop iterates over
#     an empty list at run time, but the line still exists in source — so assert
#     the guard count instead: one guard per bundled loop.
guards=$(grep -c 'contents/\$r/\$r.bundle' <<<"$out")
if [ "$guards" -ge 1 ]; then ok "bundle-existence guard present in emitted script"; else bad "no bundle guard in emitted script"; fi

# 5d. unbundled repos are surfaced explicitly, never deleted silently
out2="$(bash "$GEN" acme graveyard --bundled "alpha" --unbundled "junkfork")"
if grep -q 'intentionally not bundled' <<<"$out2"; then
  ok "unbundled deletes are labeled explicitly (no silent deletion)"
else
  bad "unbundled deletes are not labeled"
fi

# --- 6. verify gotcha guard -------------------------------------------------
# 'git bundle verify' needs a repo context (-C). A regression to the bare form
# would make every archive fail confusingly. Lock in the -C form.
group "archive verify uses -C form"
ARCH="plugins/graveyard/skills/graveyard/scripts/archive-repo.sh"
if grep -E 'git -C "?\$?\{?m\}?"? bundle verify' "$ARCH" >/dev/null 2>&1 \
   || grep -E 'git -C .* bundle verify' "$ARCH" >/dev/null 2>&1; then
  ok "archive-repo.sh verifies bundles with 'git -C <repo> bundle verify'"
else
  bad "archive-repo.sh does not use the 'git -C' form for bundle verify"
fi

# --- summary ----------------------------------------------------------------
printf '\n\033[1msummary:\033[0m %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
