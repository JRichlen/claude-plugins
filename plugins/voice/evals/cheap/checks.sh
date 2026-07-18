# Cheap eval pack for the 'voice' plugin — SOURCED by evals/cheap/run.sh
# with cwd = repo root; inherits ok/bad/group and $PLUGIN_NAME / $PLUGIN_DIR.
#
# This plugin ships only prose, so every check below greps for a load-bearing
# marker: a sentence that, if silently deleted or softened, would weaken the
# invariant while leaving three perfectly valid, well-formed SKILL.md files.
# That is exactly the regression class the structural gates cannot see.
#
# The two clauses being defended:
#   1. ROUTING — the partition is per output ELEMENT and is both exclusive and
#      exhaustive (an explicit out-of-scope list). The original drafts split
#      per response, which put a schema-inside-an-explanation in both skills at
#      once, and named no escape hatch for code or commit messages.
#   2. NO COUNTERFEIT VALIDATION — second-opinion must refuse to emit its own
#      output format when it cannot actually dispatch subagents. A fabricated
#      Verified/Flagged/Conflict block is indistinguishable from a real one to
#      the user who asked "are you sure", which makes it the worst failure in
#      the plugin.

_HV="$PLUGIN_DIR/skills/human-voice/SKILL.md"
_MV="$PLUGIN_DIR/skills/machine-voice/SKILL.md"
_SO="$PLUGIN_DIR/skills/second-opinion/SKILL.md"
_REF="$PLUGIN_DIR/skills/machine-voice/references/lexical-patterns.md"
_AG="$PLUGIN_DIR/AGENTS.md"
_HOOK="$PLUGIN_DIR/hooks/hooks.json"
_HANDLER="$PLUGIN_DIR/hooks-handlers/session-start.sh"

# has FILE PATTERN OK-MSG FAIL-MSG  — fixed-string grep
has()  { if grep -qF "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$4"; fi; }
# hasE FILE REGEX OK-MSG FAIL-MSG   — extended-regex grep
hasE() { if grep -qE "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$4"; fi; }
# lacksE FILE REGEX OK-MSG FAIL-MSG — must NOT match (negative check)
lacksE(){ if grep -qE "$2" "$1" 2>/dev/null; then bad "$4"; else ok "$3"; fi; }

# --- structure: the advertised surface exists ------------------------------
group "voice — structure"
for _f in \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" \
  "$_HV" "$_MV" "$_SO" "$_REF" \
  "$_AG" "$_HOOK" "$_HANDLER" \
  "$PLUGIN_DIR/commands/voice.md" \
  "$PLUGIN_DIR/README.md"; do
  if [ -f "$_f" ]; then ok "present: $_f"; else bad "MISSING: $_f"; fi
done

# --- clause 1: the partition is per ELEMENT, not per response --------------
group "voice — routing is element-level"
has "$_HV" 'per output element, not per response' \
  "human-voice states the partition is per output element" \
  "human-voice lost the per-ELEMENT partition — a reply mixing prose and a trace now matches both skills at once"
has "$_MV" 'per element, not per response' \
  "machine-voice states the partition is per element" \
  "machine-voice lost the per-ELEMENT partition — the two skills can now claim the same output"
has "$_MV" 'These four bullets are the whole list' \
  "machine-voice keeps the closed-list rule (no generalizing the gate)" \
  "machine-voice lost 'these four bullets are the whole list' — the gate is open-ended again and swallows prose"

# --- clause 1: the partition is EXHAUSTIVE (explicit out-of-scope) ---------
group "voice — routing is exhaustive"
has "$_HV" 'Out of scope for both skills' \
  "human-voice names the out-of-scope set (code, commit messages, creative writing)" \
  "human-voice lost the out-of-scope block — code and commit messages fall into neither voice with no instruction"
has "$_HV" 'commit messages' \
  "human-voice exempts commit messages from styling" \
  "human-voice no longer exempts commit messages — verdict-first formatting would leak into git history"
hasE "$_MV" 'this skill does not apply; follow .human-voice.' \
  "machine-voice hands non-matching elements to human-voice by name" \
  "machine-voice's exit path no longer names human-voice — non-matching output falls through to nothing"

# --- clause 1: one closed tag vocabulary across the three skills -----------
group "voice — confidence vocabulary is closed and shared"
has "$_HV" 'is reserved for' \
  "human-voice reserves the conflict glyph for second-opinion alone" \
  "human-voice lost the reserved-glyph carve-out — the tag vocabularies of the two skills now collide"
has "$_MV" 'Vocabulary collision' \
  "machine-voice distinguishes execution-status glyphs from confidence tags" \
  "machine-voice lost the vocabulary-collision warning — status and confidence markers become ambiguous"

# --- clause 2: second-opinion is offer-only --------------------------------
group "voice — second-opinion never runs unbidden"
has "$_SO" 'Never auto-run.' \
  "second-opinion keeps never-auto-run as a standalone statement" \
  "second-opinion lost 'Never auto-run' — the pipeline can fire (and bill) without the user asking"
has "$_HV" 'never invoke it unprompted' \
  "human-voice OFFERS second-opinion rather than invoking it" \
  "human-voice no longer says 'never invoke it unprompted' — it can now order the run second-opinion forbids"
lacksE "$_HV" 'Escalate to' \
  "human-voice does not command escalation" \
  "human-voice says 'Escalate to' — the imperative verb directly contradicts second-opinion's never-auto-run rule"

# --- clause 2: the ungated case must refuse, not simulate ------------------
group "voice — no counterfeit validation"
has "$_SO" 'Name the tool you will call' \
  "second-opinion requires naming the subagent tool first (a positive precondition)" \
  "second-opinion lost the name-the-tool precondition — the environment gate has no detection test again"
has "$_SO" "output format is forbidden" \
  "second-opinion forbids its own output format in the ungated case" \
  "second-opinion no longer forbids emitting its format without dispatching — a fabricated validation now satisfies the letter of the gate"
has "$_SO" 'Counts equal reality.' \
  "second-opinion binds reported counts to calls actually dispatched" \
  "second-opinion lost the counts-equal-reality rule — the delta can report work that never happened"
has "$_SO" 'Name personas, don' \
  "second-opinion requires personas be named, not counted" \
  "second-opinion lost the name-the-personas rule — a bare number hides over-cap and fabricated runs"

# --- clause 2: the pipeline's budget is internally consistent -------------
group "voice — second-opinion budget is coherent"
has "$_SO" 'Hard cap 6' \
  "second-opinion states one countable hard cap" \
  "second-opinion lost its hard cap — the fan-out has no ceiling"
has "$_SO" 'Do not spawn one call per claim' \
  "second-opinion batches fact-checking so the cap is reachable" \
  "second-opinion reverted to per-claim fan-out, which blows the cap before any advisor runs"
has "$_SO" 'Cut > Conflict > Flagged > Verified' \
  "second-opinion states group precedence, so merges are deterministic" \
  "second-opinion lost the group precedence order — a claim can land in two groups and two runs disagree"

# --- cross-harness: the hook is a convenience, never a dependency ---------
group "voice — hook degrades gracefully"
has "$_HOOK" 'SessionStart' \
  "hooks.json registers the SessionStart injection" \
  "hooks.json no longer registers SessionStart — the always-on routing rule never loads"
has "$_HOOK" 'startup|clear|compact' \
  "hooks.json re-fires after compaction so routing survives context loss" \
  "hooks.json lost the compact matcher — routing silently disappears after a compaction"
has "$_HANDLER" 'additionalContext' \
  "the handler emits additionalContext (the documented injection contract)" \
  "the handler no longer emits additionalContext — the hook runs but injects nothing"
has "$_AG" 'convenience, never a dependency' \
  "AGENTS.md states the hook is a convenience, not a dependency" \
  "AGENTS.md dropped the convenience-not-dependency statement — the cross-harness promise is undocumented"
for _s in "$_HV" "$_MV" "$_SO"; do
  lacksE "$_s" 'nvoked by hook|hook invokes this skill|runs on every response' \
    "no hook-mechanism claim in $_s" \
    "$_s claims a hook invokes it — that mechanism claim is false on every harness that does not read hooks.json"
done

# --- regression: the superseded duplicate generation stays gone -----------
group "voice — superseded duplicates not reintroduced"
for _s in "$_HV" "$_MV" "$_SO"; do
  lacksE "$_s" 'communication-stack|response-style' \
    "no reference to the superseded skill names in $_s" \
    "$_s references communication-stack/response-style — the duplicate generation whose identical descriptions made skill selection nondeterministic"
done
lacksE "$_HV" 'ask_user_input' \
  "human-voice does not name a nonexistent tool for asking questions" \
  "human-voice references ask_user_input, a tool that does not exist here — the ambiguous branch becomes unfollowable"

# --- prose rules a behavioral judge is scored against --------------------
group "voice — human-voice rules are single-valued"
has "$_HV" 'No paragraph exceeds 4 sentences.' \
  "human-voice states one paragraph limit" \
  "human-voice's paragraph limit is no longer single-valued — a judge cannot score it"
has "$_HV" 'first line of the response' \
  "human-voice makes verdict placement text-observable" \
  "human-voice lost the observable verdict-placement predicate"

unset _HV _MV _SO _REF _AG _HOOK _HANDLER _s _f
