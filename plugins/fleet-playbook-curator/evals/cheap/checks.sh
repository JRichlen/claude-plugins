# Cheap eval pack for the 'fleet-playbook-curator' plugin — SOURCED by evals/cheap/run.sh
# with cwd = repo root; inherits ok/bad/group and $PLUGIN_NAME / $PLUGIN_DIR.
#
# What the cheap tier defends is this plugin's invariant: the fleet-playbook is a
# curated INDEX, never the source of truth — facts auto-commit, interpretation is
# PR-only, every claim is citable. Each check below turns a silent regression of
# that invariant (soften the banner, flip source-of-truth, let curate push to main,
# drop the sha requirement, make the diff nondeterministic) into a red build.

SK="$PLUGIN_DIR/skills/fleet-playbook-curator"
PB="$SK/templates/fleet-playbook"
SYNC="$SK/templates/fleet-sync.yml"
FX="$PLUGIN_DIR/evals/cheap/fixtures"

has()   { if grep -qF "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$4"; fi; }
hasE()  { if grep -qE "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$4"; fi; }
lacksE(){ if grep -qE "$2" "$1" 2>/dev/null; then bad "$4"; else ok "$3"; fi; }

# --- structure: the advertised surface exists ------------------------------
group "fleet-playbook-curator — structure"
for f in \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  "$SK/SKILL.md" "$SK/PROMPT.md" \
  "$SK/scripts/list-fleet-members.sh" "$SK/scripts/diff-fleet.sh" \
  "$SK/scripts/gather-context.sh" "$SK/scripts/scaffold-repo.sh" \
  "$SYNC" "$SK/templates/fleet.example.yaml" \
  "$PB/SKILL.md" "$PB/index.schema.json" "$PB/index.seed.json" "$PB/CHANGELOG.md" \
  "$PLUGIN_DIR/agents/fleet-playbook-curator.md" \
  "$PLUGIN_DIR/commands/deploy-fleet-playbook.md" \
  "$PLUGIN_DIR/commands/curate-fleet-playbook.md" \
  "$PLUGIN_DIR/docs/DESIGN.md"; do
  if [ -f "$f" ]; then ok "present: ${f#$PLUGIN_DIR/}"; else bad "MISSING: ${f#$PLUGIN_DIR/}"; fi
done

# --- invariant: the playbook template declares itself non-authoritative -----
group "fleet-playbook-curator — non-authoritative by construction"
has "$PB/SKILL.md" 'source-of-truth: false' \
  "playbook template carries source-of-truth: false frontmatter" \
  "playbook template lost the source-of-truth: false key — it can now read as authoritative"
has "$PB/SKILL.md" 'NOT the source of truth' \
  "playbook template keeps the non-authoritative banner" \
  "playbook template banner ('NOT the source of truth') was removed/softened"
lacksE "$PB/SKILL.md" 'source-of-truth:[[:space:]]*true' \
  "playbook template never sets source-of-truth: true" \
  "playbook template sets source-of-truth: true — breaks the invariant"

# --- invariant: every claim must cite a real sha ---------------------------
group "fleet-playbook-curator — citation ledger requires a real sha"
hasE "$PB/index.schema.json" '"required":[[:space:]]*\[[^]]*"repo"[^]]*"path"[^]]*"sha"[^]]*"curated_at"' \
  "index schema requires repo+path+sha+curated_at on every claim" \
  "index schema no longer requires the full repo/path/sha/curated_at citation tuple"
hasE "$PB/index.schema.json" '\[0-9a-f\]\{7,40\}' \
  "index schema pins sha to a real hex commit (no placeholders)" \
  "index schema dropped the hex-sha pattern — placeholder shas would validate"

# --- invariant: facts auto-commit, interpretation is PR-only ----------------
group "fleet-playbook-curator — detect(no-LLM) / curate(PR-only) split"
detect_block="$(awk '/^  detect:/{f=1} /^  curate:/{f=0} f' "$SYNC")"
curate_block="$(awk '/^  curate:/{f=1} f' "$SYNC")"
if printf '%s' "$detect_block" | grep -q 'ANTHROPIC_API_KEY'; then
  bad "detect job references ANTHROPIC_API_KEY — the detector must be LLM-free"
else ok "detect job is LLM-free (no LLM credential)"; fi
if printf '%s' "$detect_block" | grep -qE 'push +origin +HEAD:main'; then
  ok "detect job auto-commits facts to main"
else bad "detect job no longer pushes the facts manifest to main"; fi
if printf '%s' "$curate_block" | grep -q 'gh pr create'; then
  ok "curate job lands changes via a PR"
else bad "curate job does not open a PR (gh pr create missing) — interpretation could reach main unreviewed"; fi
if printf '%s' "$curate_block" | grep -qE 'push +origin +HEAD:main|push +[^ ]*:main\b'; then
  bad "curate job pushes to main — interpretation must be PR-only"
else ok "curate job never pushes to main (PR-only)"; fi

# --- determinism: the diff is a pure function -------------------------------
group "fleet-playbook-curator — deterministic diff"
if command -v jq >/dev/null 2>&1; then
  d1="$(bash "$SK/scripts/diff-fleet.sh" "$FX/old-manifest.json" "$FX/new-manifest.json" 2>/dev/null)"
  d2="$(bash "$SK/scripts/diff-fleet.sh" "$FX/old-manifest.json" "$FX/new-manifest.json" 2>/dev/null)"
  if [ -n "$d1" ] && [ "$d1" = "$d2" ]; then ok "diff-fleet.sh is byte-deterministic on the fixture"
  else bad "diff-fleet.sh produced differing/empty output across runs (nondeterministic)"; fi
  if printf '%s' "$d1" | jq -e '.changed==true and (.added|length)==1 and (.removed|length)==1 and (.renamed|length)==1 and (.updated|length)==1' >/dev/null 2>&1; then
    ok "diff-fleet.sh classifies add/remove/rename(by node_id)/update correctly"
  else bad "diff-fleet.sh misclassified the fixture (expected 1 each of add/remove/rename/update)"; fi
else
  ok "jq unavailable — skipping determinism exec check (structural checks still enforced)"
fi

# --- scripts parse + JSON is valid -----------------------------------------
group "fleet-playbook-curator — scripts parse, JSON valid"
for s in "$SK"/scripts/*.sh; do
  if bash -n "$s" 2>/dev/null; then ok "bash -n ok: ${s#$PLUGIN_DIR/}"; else bad "bash -n FAILED: ${s#$PLUGIN_DIR/}"; fi
done
for j in "$PB/index.schema.json" "$PB/index.seed.json" "$FX/old-manifest.json" "$FX/new-manifest.json"; do
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$j" 2>/dev/null; then ok "valid JSON: ${j#$PLUGIN_DIR/}"; else bad "INVALID JSON: ${j#$PLUGIN_DIR/}"; fi
done

# --- portability: the agent seam is swappable ------------------------------
group "fleet-playbook-curator — cross-harness seam"
has "$SYNC" 'AGENT_CMD' \
  "curate workflow exposes a swappable AGENT_CMD (not hard-wired to one harness)" \
  "curate workflow hard-wires the agent invocation — lost the cross-harness seam"
