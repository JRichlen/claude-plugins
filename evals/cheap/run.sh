#!/usr/bin/env bash
#
# Cheap evals — deterministic, offline, no API cost. Runs in well under a second.
#
# This is the tier that must pass on EVERY change before commit (see AGENTS.md).
# It proves the structural + safety invariants that don't need an LLM to check:
# a bad edit to a delete-script generator that dropped a bundle guard, a
# malformed manifest, an unparseable script, or a marketplace source pointing at
# a plugin that isn't there would all be caught here for free.
#
# STRUCTURE: sections 1-4 are GENERIC — they auto-discover every plugin's files
# and hold for any plugin added to this marketplace. The plugin-SPECIFIC safety
# checks live with each plugin, in plugins/<name>/evals/cheap/checks.sh, and are
# sourced here per plugin enumerated from marketplace.json (section 5). Discovery
# FAILS CLOSED: a plugin registered in the marketplace with no cheap eval pack is
# a failure, not a silent skip — otherwise a new plugin could ship with zero
# safety coverage and still show green.
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

# --- 5. Per-plugin safety checks (fail-closed discovery) -------------------
# Enumerate every plugin registered in the marketplace and source its cheap eval
# pack. A registered plugin MUST ship plugins/<source>/evals/cheap/checks.sh —
# a missing pack is a FAILURE, never a skip, so no plugin can ship without the
# deterministic safety checks the cheap tier exists to enforce. Each pack runs
# with cwd = repo root and inherits ok/bad/group above; PLUGIN_NAME / PLUGIN_DIR
# are exported for packs that prefer plugin-relative paths.
while IFS= read -r entry; do
  PLUGIN_NAME="${entry%%$'\t'*}"
  PLUGIN_SRC="${entry#*$'\t'}"
  PLUGIN_DIR="$PLUGIN_SRC"
  pack="$PLUGIN_SRC/evals/cheap/checks.sh"
  if [ -f "$pack" ]; then
    export PLUGIN_NAME PLUGIN_DIR
    # shellcheck source=/dev/null
    . "$pack"
  else
    group "plugin '$PLUGIN_NAME' cheap eval pack"
    bad "plugin '$PLUGIN_NAME' ($PLUGIN_SRC) has no cheap eval pack at $pack"
  fi
done < <(python3 - "$REPO_ROOT" <<'PY'
import json, os, sys
root = sys.argv[1]
mkt = json.load(open(os.path.join(root, ".claude-plugin", "marketplace.json")))
for p in mkt.get("plugins", []):
    src = (p.get("source", "") or "").lstrip("./")
    print(f"{p.get('name','')}\t{src}")
PY
)

# --- summary ----------------------------------------------------------------
printf '\n\033[1msummary:\033[0m %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
