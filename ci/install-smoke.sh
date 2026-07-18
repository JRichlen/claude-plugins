#!/usr/bin/env bash
#
# install-smoke.sh <plugin-name> — headless, cross-harness "does this plugin
# install from the marketplace" smoke test for ONE registered plugin.
#
# The marketplace claims "works with any agent", so this check deliberately does
# NOT depend on an interactive Claude Code session or the `claude` CLI (whose
# plugin schema is a separately-versioned upstream dependency that can drift). It
# is a PORTABLE, offline, structural resolve-and-parse check: it walks the same
# path a harness follows to install a plugin — marketplace.json source ->
# .claude-plugin/plugin.json -> the declared component directories — and asserts
# every hop resolves and parses. If a plugin is wired such that a real installer
# would choke (missing source dir, malformed manifest, a declared component path
# that isn't there, an unfilled {{template}} token, a SKILL.md with no
# frontmatter), this fails before that plugin could ship.
#
# It reuses the exact conventions of evals/cheap/run.sh (sections 3, 4, 6): the
# marketplace-wiring resolution, the SKILL.md frontmatter contract, and the
# no-unfilled-placeholder scan — scoped to the single target plugin so the
# `install` matrix can attribute a failure to one plugin.
#
# Exit 0 = the plugin installs structurally. Exit 1 = at least one check failed.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PLUGIN_NAME="${1:-}"
if [ -z "$PLUGIN_NAME" ]; then
  echo "usage: ci/install-smoke.sh <plugin-name>" >&2
  exit 2
fi

python3 - "$REPO_ROOT" "$PLUGIN_NAME" <<'PY'
import json, os, re, sys

root, want = sys.argv[1], sys.argv[2]
passed = failed = 0

def ok(msg):
    global passed
    print(f"  PASS {msg}")
    passed += 1

def bad(msg):
    global failed
    print(f"  FAIL {msg}")
    failed += 1

def group(title):
    print(f"\n{title}")

# --- resolve the plugin via the marketplace lockfile (run.sh §3) ------------
group(f"install smoke — {want}: marketplace wiring")
mkt = json.load(open(os.path.join(root, ".claude-plugin", "marketplace.json")))
entry = next((p for p in mkt.get("plugins", []) if p.get("name") == want), None)
if entry is None:
    bad(f"'{want}' is not registered in .claude-plugin/marketplace.json")
    print(f"\nsummary: {passed} passed, {failed} failed")
    sys.exit(1)

src = entry.get("source", "") or ""
src = src[2:] if src.startswith("./") else src
src = src.rstrip("/")
plugin_dir = os.path.join(root, src)
if os.path.isdir(plugin_dir):
    ok(f"marketplace source '{src}' resolves to an existing directory")
else:
    bad(f"marketplace source '{src}' does not resolve to a directory")
    print(f"\nsummary: {passed} passed, {failed} failed")
    sys.exit(1)

# --- plugin.json exists, parses, and matches (run.sh §3) --------------------
manifest_path = os.path.join(plugin_dir, ".claude-plugin", "plugin.json")
if not os.path.isfile(manifest_path):
    bad(f"{src}/.claude-plugin/plugin.json is missing")
    print(f"\nsummary: {passed} passed, {failed} failed")
    sys.exit(1)
try:
    pj = json.load(open(manifest_path))
    ok(f"{src}/.claude-plugin/plugin.json is valid JSON")
except Exception as e:  # noqa: BLE001
    bad(f"{src}/.claude-plugin/plugin.json is not valid JSON: {e}")
    print(f"\nsummary: {passed} passed, {failed} failed")
    sys.exit(1)

if pj.get("name") == want:
    ok(f"plugin.json name matches marketplace ('{want}')")
else:
    bad(f"plugin.json name '{pj.get('name')}' != marketplace name '{want}'")

for field in ("version", "description"):
    val = pj.get(field)
    if isinstance(val, str) and val.strip():
        ok(f"plugin.json .{field} is a non-empty string")
    else:
        bad(f"plugin.json .{field} is missing or empty")

# --- declared component paths resolve ---------------------------------------
# For each of skills/commands/agents: if the manifest DECLARES the key, whatever
# it points at must exist on disk. A string is a directory (the convention every
# plugin.json here uses); a list is an explicit set of file paths (the shape the
# real plugin schema enforces for the `agents` key), each of which must be a real
# file, not a directory. A key that is ABSENT is not required — but if the
# conventional dir happens to exist it is reported for visibility.
group(f"install smoke — {want}: declared components resolve")
for key in ("skills", "commands", "agents"):
    if key in pj:
        val = pj[key]
        if isinstance(val, str):
            rel = val.lstrip("./").rstrip("/")
            target = os.path.join(plugin_dir, rel)
            if os.path.exists(target):
                ok(f"'{key}': './{rel}' exists")
            else:
                bad(f"'{key}': declared path './{rel}' does not exist")
        elif isinstance(val, list):
            if not val:
                bad(f"'{key}': declared as an empty list")
            for item in val:
                rel = str(item).lstrip("./")
                target = os.path.join(plugin_dir, rel)
                if os.path.isfile(target):
                    ok(f"'{key}': file './{rel}' exists")
                else:
                    bad(f"'{key}': declared file './{rel}' is not a real file")
        else:
            bad(f"'{key}': unexpected type {type(val).__name__} (want string or list)")
    else:
        conventional = os.path.join(plugin_dir, key)
        if os.path.isdir(conventional):
            ok(f"'{key}': not declared, conventional ./{key}/ dir present (optional)")

# --- every SKILL.md parses with name+description frontmatter (run.sh §4) -----
group(f"install smoke — {want}: SKILL.md frontmatter parses")
skill_md = []
for base, _, files in os.walk(plugin_dir):
    for f in files:
        if f == "SKILL.md":
            skill_md.append(os.path.join(base, f))
if not skill_md:
    # A plugin need not ship a skill (it could be commands/agents only), so this
    # is informational, not a failure.
    ok("no SKILL.md files to validate")
for sm in sorted(skill_md):
    rel = os.path.relpath(sm, root)
    txt = open(sm, encoding="utf-8", errors="replace").read()
    if not txt.startswith("---"):
        bad(f"{rel} has no frontmatter"); continue
    parts = txt.split("---", 2)
    if len(parts) < 3:
        bad(f"{rel} frontmatter is not closed with a second '---'"); continue
    fm = parts[1]
    missing = [k for k in ("name:", "description:") if k not in fm]
    if missing:
        bad(f"{rel} frontmatter missing {', '.join(missing)}")
    else:
        ok(f"{rel} frontmatter has name + description")

# --- every shipped *.md is readable UTF-8; closed frontmatter if present -----
group(f"install smoke — {want}: markdown files parse")
md_bad = 0
md_seen = 0
for base, _, files in os.walk(plugin_dir):
    for f in files:
        if not f.endswith(".md"):
            continue
        p = os.path.join(base, f)
        if os.path.islink(p):
            continue
        md_seen += 1
        try:
            txt = open(p, encoding="utf-8").read()
        except UnicodeDecodeError:
            bad(f"{os.path.relpath(p, root)} is not valid UTF-8"); md_bad += 1; continue
        if txt.startswith("---") and len(txt.split("---", 2)) < 3:
            bad(f"{os.path.relpath(p, root)} opens frontmatter but never closes it"); md_bad += 1
if md_bad == 0:
    ok(f"all {md_seen} markdown file(s) are valid UTF-8 with well-formed frontmatter")

# --- no unfilled {{placeholder}} tokens (run.sh §6, scoped) -----------------
group(f"install smoke — {want}: no unfilled template tokens")
ph = 0
for base, _, files in os.walk(plugin_dir):
    for f in files:
        if not (f.endswith(".md") or f.endswith(".json")):
            continue
        p = os.path.join(base, f)
        if os.path.islink(p):
            continue
        try:
            if "{{" in open(p, encoding="utf-8").read():
                bad(f"{os.path.relpath(p, root)} still contains an unfilled {{{{...}}}} token"); ph += 1
        except UnicodeDecodeError:
            bad(f"{os.path.relpath(p, root)} is not valid UTF-8"); ph += 1
if ph == 0:
    ok("no unfilled placeholder tokens in this plugin's prose or manifests")

print(f"\nsummary: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
