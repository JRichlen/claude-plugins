# Cheap eval pack for the 'plugin-factory' plugin — SOURCED by evals/cheap/run.sh
# with cwd = repo root; inherits ok/bad/group and $PLUGIN_NAME / $PLUGIN_DIR.
#
# plugin-factory's job is to generate correct plugin skeletons, so its invariant
# is DOGFOODED: scaffold a throwaway plugin into a temp marketplace root and
# assert the output shape the rest of the cheap tier depends on. If the generator
# ever stops producing a valid, fully-filled, red-by-default skeleton, this goes
# red — the factory is held to the same bar it imposes on everything it makes.
#
# The scaffold is deterministic (no timestamps/randomness in generated content),
# so these assertions are stable across runs.

group "plugin 'plugin-factory' scaffold dogfood"

_scaffold="$PLUGIN_DIR/skills/plugin-factory/scripts/scaffold-plugin.sh"
if [ ! -x "$_scaffold" ]; then
  bad "plugin-factory: scaffold-plugin.sh missing or not executable at $_scaffold"
else
  _tmp="$(mktemp -d)"
  mkdir -p "$_tmp/.claude-plugin" "$_tmp/plugins"
  printf '{\n  "name": "dogfood",\n  "plugins": []\n}\n' > "$_tmp/.claude-plugin/marketplace.json"

  if "$_scaffold" sample-plugin \
        --description "A sample plugin for the dogfood eval." \
        --invariant "The sample invariant always holds." \
        --root "$_tmp" >/dev/null 2>&1; then
    ok "plugin-factory: scaffold sample-plugin exits 0"
  else
    bad "plugin-factory: scaffold sample-plugin failed to run"
  fi

  _gen="$_tmp/plugins/sample-plugin"

  # Every file the marketplace conventions require is present.
  _missing=""
  for f in \
    ".claude-plugin/plugin.json" \
    "skills/sample-plugin/SKILL.md" \
    "commands/sample-plugin.md" \
    "AGENTS.md" "CLAUDE.md" "GEMINI.md" "README.md" \
    "evals/cheap/checks.sh"; do
    [ -e "$_gen/$f" ] || _missing="$_missing $f"
  done
  if [ -z "$_missing" ]; then ok "plugin-factory: scaffold emits the full skeleton"
  else bad "plugin-factory: scaffold missing files:$_missing"; fi

  # Cross-harness symlinks resolve to AGENTS.md.
  if [ -L "$_gen/CLAUDE.md" ] && [ -L "$_gen/GEMINI.md" ] \
     && [ "$(readlink "$_gen/CLAUDE.md")" = "AGENTS.md" ] \
     && [ "$(readlink "$_gen/GEMINI.md")" = "AGENTS.md" ]; then
    ok "plugin-factory: CLAUDE.md/GEMINI.md symlink to AGENTS.md"
  else
    bad "plugin-factory: cross-harness symlinks not wired to AGENTS.md"
  fi

  # plugin.json is valid JSON and names the plugin.
  if python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('name')=='sample-plugin' and d.get('version')=='0.0.1' else 1)" "$_gen/.claude-plugin/plugin.json" 2>/dev/null; then
    ok "plugin-factory: generated plugin.json is valid and names the plugin (v0.0.1)"
  else
    bad "plugin-factory: generated plugin.json invalid or misnamed"
  fi

  # SKILL.md leads with the invariant section (#3 invariant-first).
  if grep -q '^## Invariant' "$_gen/skills/sample-plugin/SKILL.md" 2>/dev/null; then
    ok "plugin-factory: SKILL.md carries an '## Invariant' section (invariant-first)"
  else
    bad "plugin-factory: SKILL.md missing the '## Invariant' section"
  fi

  # No unfilled {{placeholder}} tokens leaked into the output.
  if grep -rqF '{{' "$_gen" 2>/dev/null; then
    bad "plugin-factory: generated skeleton still contains {{placeholder}} tokens"
  else
    ok "plugin-factory: no unfilled placeholder tokens in output"
  fi

  # Red-by-default (#13): the generated eval stub carries the sentinel.
  if grep -q 'SCAFFOLD-UNIMPLEMENTED-' "$_gen/evals/cheap/checks.sh" 2>/dev/null; then
    ok "plugin-factory: generated eval stub is red-by-default (sentinel present)"
  else
    bad "plugin-factory: generated eval stub is not red-by-default (no sentinel)"
  fi

  # Lockfile (#6): the new plugin was wired into the marketplace, once.
  if python3 -c "import json,sys; m=json.load(open(sys.argv[1])); ns=[p.get('name') for p in m.get('plugins',[])]; sys.exit(0 if ns.count('sample-plugin')==1 else 1)" "$_tmp/.claude-plugin/marketplace.json" 2>/dev/null; then
    ok "plugin-factory: scaffold wired exactly one marketplace entry"
  else
    bad "plugin-factory: scaffold did not wire the marketplace entry exactly once"
  fi

  rm -rf "$_tmp"
  unset _scaffold _tmp _gen _missing
fi

# --- Wave 3: the wrapped skill-iteration loop --------------------------------
# The factory doesn't just scaffold a red skeleton; it ships the discipline for
# turning that skeleton into a skill that beats a baseline. Those artifacts —
# the SHA-pinned upstream wrap (#9), the file-based handoff templates (#7), the
# advisory delta gate (#4), and the contamination/stuck guards (#14) — are held
# to the same deterministic bar. Each is checkable offline, so none can rot into
# a good intention.
group "plugin 'plugin-factory' skill-iteration loop (wave 3)"

_skill="$PLUGIN_DIR/skills/plugin-factory"

# #9 — the skill-creator pin is well-formed: a real 40-hex commit, not a moving
# branch ref, so an upstream bump is a reviewable one-line SHA change.
_pin="$_skill/vendor/skill-creator.pin"
if python3 - "$_pin" <<'PY' 2>/dev/null; then
import re, sys
kv = {}
for line in open(sys.argv[1]):
    line = line.strip()
    if not line or line.startswith("#") or ":" not in line:
        continue
    k, v = line.split(":", 1)
    kv[k.strip()] = v.strip()
need = ("repo", "path", "ref", "sha")
sys.exit(0 if all(kv.get(k) for k in need) and re.fullmatch(r"[0-9a-f]{40}", kv["sha"]) else 1)
PY
  ok "plugin-factory: skill-creator.pin is well-formed (40-hex sha, wrap not fork)"
else
  bad "plugin-factory: skill-creator.pin missing, malformed, or sha is not a 40-hex commit"
fi

# #7 — the three file-based handoff templates + the reference exist. These are
# the seam that lets the loop cross a harness boundary via committed files.
_missing=""
for f in \
  "templates/handoff/BRIEF.md" \
  "templates/handoff/INTENT.md" \
  "templates/handoff/STUCK.md" \
  "references/skill-iteration.md"; do
  [ -e "$_skill/$f" ] || _missing="$_missing $f"
done
if [ -z "$_missing" ]; then ok "plugin-factory: handoff templates + skill-iteration reference present"
else bad "plugin-factory: skill-iteration artifacts missing:$_missing"; fi

# #4 — the delta gate self-tests AND self-declares advisory (its --self-test
# asserts MODE is advisory, so a flip to blocking without a deliberate edit fails).
if python3 "$_skill/scripts/delta_gate.py" --self-test >/dev/null 2>&1; then
  ok "plugin-factory: delta_gate.py self-test (advisory-only lift gate)"
else
  bad "plugin-factory: delta_gate.py self-test failed"
fi

# #14 — the contamination + stuck-budget guard self-tests.
if python3 "$_skill/scripts/check_baseline_integrity.py" --self-test >/dev/null 2>&1; then
  ok "plugin-factory: check_baseline_integrity.py self-test (contamination + stuck guards)"
else
  bad "plugin-factory: check_baseline_integrity.py self-test failed"
fi

# #14 — the shipped STUCK.md template carries a live budget the guard can read.
if python3 "$_skill/scripts/check_baseline_integrity.py" --stuck "$_skill/templates/handoff/STUCK.md" >/dev/null 2>&1; then
  ok "plugin-factory: STUCK.md template exposes a readable, non-exhausted budget"
else
  bad "plugin-factory: STUCK.md template budget is missing or already exhausted"
fi

unset _skill _pin _missing
