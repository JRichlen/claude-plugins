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
